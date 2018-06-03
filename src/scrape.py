#!/usr/bin/env python

"""
Scraping utility for the CTA Bus Tracker API.
For usage information, run "python scrape.py" on your command line.

Copyright 2018 Active Transportation Alliance

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""
from __future__ import print_function
import os
import sys
import getpass
try:
    from itertools import zip_longest
except ImportError:
    from itertools import izip_longest as zip_longest
import argparse
import requests
import psycopg2
from psycopg2.extras import execute_batch

"""
Scrape current vehicle positions and patterns from
the CTA Bus Tracker API and load into a postgres database.
"""

API = 'http://www.ctabustracker.com/bustime/api/v2/{}'

"""
"vid": "7934", vehicle_id
"tmstmp": "20180321 17:27", timestamp with time zone
"lat": "41.878145", latitude
"lon": "-87.63962666666667", longitude
"hdg": "88", bearing
"pid": 6351, pattern_id
"rt": "1", route_id
"des": "35th/Michigan", destination text
"pdist": 103, pattern_dist
"dly": false, delayed boolean
"tatripid": "66", trip_id
"tablockid": "1 -751", tablockid text
"zone": "" zone text
"""

INSERT_POSITIONS = """
    INSERT INTO cta.positions (
        timestamp, vehicle_id, latitude, longitude, bearing, pattern_id, route_id,
        destination, dist_along_route, delayed, trip_id, tablockid, zone
    ) VALUES (
        %(tmstmp)s::timestamp without time zone at time zone 'US/Central',
        %(vid)s, %(lat)s::numeric, %(lon)s::numeric, %(hdg)s::integer, %(pid)s, %(rt)s,
        %(des)s, %(pdist)s, %(dly)s::boolean, %(tatripid)s, %(tablockid)s, %(zone)s
    ) ON CONFLICT DO NOTHING
"""

INSERT_PATTERNS = """
    INSERT INTO cta.patterns ("pid", "length", "route_direction")
    VALUES (%(pid)s::integer, %(ln)s, %(rtdir)s)
    ON CONFLICT DO NOTHING
"""

INSERT_PATTERN_STOPS = """
    INSERT INTO cta.pattern_stops (
        pid, stop_id, stop_name, stop_sequence, pdist, latitude, longitude, type
    ) VALUES (
        %(pid)s::int, %(stpid)s, %(stpnm)s, %(seq)s, %(pdist)s,
        %(lat)s::numeric, %(lon)s::numeric, %(typ)s
    ) ON CONFLICT DO NOTHING
"""


def grouper(n, iterable, fillvalue=None):
    """grouper(3, 'ABCDEFG', 'x') --> ABC DEF Gxx"""
    args = [iter(iterable)] * n
    return zip_longest(fillvalue=fillvalue, *args)


def fetch_routeids(session):
    """Request current route IDs from the API."""
    r = session.get(API.format('getroutes'))
    routes = r.json().get('bustime-response').get('routes')
    return [r['rt'] for r in routes]


def fetch_positions(api_key):
    """Request positions from the API."""
    positions = []
    with requests.Session() as session:
        session.params = {'key': api_key, 'format': 'json'}

        # get routes
        routeids = fetch_routeids(session)

        # Loop through routes getting vehicles 10 at a time
        for grp in grouper(10, routeids, ','):
            params = {
                'rt': ','.join(grp).strip(',')
            }
            raw = session.get(API.format('getvehicles'), params=params)
            vehicles = raw.json().get('bustime-response').get('vehicle')
            try:
                positions.extend(vehicles)
            except TypeError:
                pass

    return positions


def fetch_patterns(api_key, pids):
    """Request patterns from the API."""
    patterns = []
    with requests.Session() as session:
        session.params = {'key': api_key, 'format': 'json'}

        # Loop through routes getting vehicles 10 at a time
        for grp in grouper(10, (str(p) for p in pids), ','):
            params = {
                'pid': ','.join(grp).strip(',')
            }
            raw = session.get(API.format('getpatterns'), params=params)
            pattern = raw.json().get('bustime-response').get('ptr')
            try:
                patterns.extend(pattern)
            except TypeError:
                pass

    return patterns


def get_current_pids(cursor):
    """
    Get extant pattern IDs from the the DB,
    to be compared against new ones in the feed.
    """
    cursor.execute('select pid from cta.patterns')
    return set(row[0] for row in cursor.fetchall())


def connection_params():
    pg = {
        'PGUSER': 'user',
        'PGHOST': 'host',
        'PGPORT': 'port',
        'PGPASSWORD': 'password',
        'PGPASSFILE': 'passfile',
    }
    params = {'dbname': os.environ.get('PGDATABASE', getpass.getuser())}
    params.update({v: os.environ[k] for k, v in pg.items() if k in os.environ})
    return params


def main():
    """Scrape positions."""
    desc = """
        Scrape CTA bus positions into a PostgreSQL database.
        By default, a local connection to your user's database will be created.
        To specify other connection parameters, use the standard PG* environment variables.
    """
    parser = argparse.ArgumentParser(description=desc)
    parser.add_argument('--key', default=os.environ.get('CTA_API_KEY'))
    parser.add_argument('--positions', action='store_true', help='fetch positions')
    parser.add_argument('--patterns', action='store_true', help='fetch patterns')
    args = parser.parse_args()

    with psycopg2.connect(**connection_params()) as conn:
        cursor = conn.cursor()

        if args.positions:
            positions = fetch_positions(args.key)
            execute_batch(cursor, INSERT_POSITIONS, positions)
            print('inserted', len(positions), 'positions', file=sys.stderr)
            conn.commit()

        if args.positions and args.patterns:
            current_pids = get_current_pids(cursor)
            pids = set(x['pid'] for x in positions).difference(current_pids)

            if not pids:
                print('No new patterns', file=sys.stderr)

            else:
                patterns = fetch_patterns(args.key, pids)
                execute_batch(cursor, INSERT_PATTERNS, patterns)
                print('inserted', len(patterns), 'patterns', file=sys.stderr)
                conn.commit()

                patternstops = [
                    dict(pid=x['pid'], **stop)
                    for x in patterns
                    for stop in x['pt']
                ]
                for patternstop in patternstops:
                    patternstop.setdefault('stpid')
                    patternstop.setdefault('stpnm')

                execute_batch(cursor, INSERT_PATTERN_STOPS, patternstops)
                print('inserted', len(patternstops), 'patternstops', file=sys.stderr)
                conn.commit()


if __name__ == '__main__':
    main()
