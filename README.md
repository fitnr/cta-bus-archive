# cta bus archiver

Archives bus positions served by the [CTA Bus Tracker](https://www.transitchicago.com/developers/bustracker/) API.

## Active Transportation Alliance archive

The Active Transportation Alliance maintains a daily archive of Bus Tracker data. The data is in `.xz` compressed CSV format. There are three files for each day, following this pattern:
```
https://s3.us-east-2.amazonaws.com/chibus/yyyy/mm/yyyy-mm-dd-pattern_stops.csv.xz
https://s3.us-east-2.amazonaws.com/chibus/yyyy/mm/yyyy-mm-dd-patterns.csv.xz
https://s3.us-east-2.amazonaws.com/chibus/yyyy/mm/yyyy-mm-dd-positions.csv.xz
```

For example: `https://s3.us-east-2.amazonaws.com/chibus/2018/03/2018-03-22-pattern_stops.csv.xz`.

The archive begins in October, 2018. Some data is also available for selected days starting in March, 2018.

## Requirements

* Make in a bash environment
* Python (2.7+ or 3.5+)
* PostGreSQL (9.5+)

## Install

Get a CTA [Bus Tracker](https://www.transitchicago.com/developers/bustracker/) API key.

Install PostgreSQL on your system and create a database.

Create environment variables to track how you log into the db (which could be remote).

````bash
export CTA_API_KEY=<api key>
````
Optionally, add these variables for connection to a Postgres database. This isn't necessary if you're using an eponymous postgres user to connect to an eponymous database over the socket.
````bash
export PGUSER=<defaults to your user>
export PGDATABASE=<defaults to your user>
export PGHOST=<defaults to socket>
export PGPORT=<defaults to 5432>
````

Use a [`.pgpass`](https://www.postgresql.org/docs/current/static/libpq-pgpass.html) file to save a password, if one is needed.

Run the following will set up the database and install Python dependencies
```
make init
```

## Scrape

To save the current snapshot of bus positions:
```
python src/scrape.py --positions
```

or, for short:
```
make scrape
```

This will update the Postgres database with current positions as well as new bus patterns.

## Scheduling

See `crontab.txt` for a sample cron job that schedules regular fetches from the API.

### Details about CTA standards

* CTA service standards define AM peak as 6-9 am and PM peak as 3-7 pm.

* CTA defines on-time performance as trips leaving the terminal no more than 1 minute ahead of schedule and no more than 5 minutes later than schedule.

* Bus bunching is defined as buses that depart the same timepoint within 60 seconds of each other. This is calculated as percentage of all buses that passed through the timepoint.


## License

Copyright 2018 Active Transportation Alliance. Licensed under the Apache License, Version 2.0.