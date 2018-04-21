# cta bus archiver

Archive bus positions served by the [CTA Bus Tracker](https://www.transitchicago.com/developers/bustracker/) API.

## Requirements

* Python (2.7+ or 3.5+)
* PostGreSQL (9.5+)

## Install

Get a CTA [Bus Tracker](https://www.transitchicago.com/developers/bustracker/) API key.

Install PostgreSQL on your system and create a database.

Create environment variables to track how you log into the db (which could be remote).

````
export CTA_API_KEY=<api key>
export PGUSER=<user> # defaults to your user
export PGDATABASE=<dbname> # defaults to your user
export PGHOST=<xyz> # defaults to socker
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
make -e scrape
```

This will update the Postgres database with current positions as well as new bus patterns.

## Scheduling

See `crontab.txt` for a sample cron job that schedules regular fetches from the API.