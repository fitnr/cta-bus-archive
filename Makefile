shell = bash

PYTHON = python

PG_HOST ?=
PG_PORT ?=
PG_USER ?=
PG_DATABASE ?=
PSQLFLAGS = $(PG_DATABASE)

CONNECTION = dbname=$(PG_DATABASE)

ifdef PG_HOST
CONNECTION += host=$(PG_HOST)
PSQLFLAGS += -h $(PG_HOST)
endif

ifdef PG_PORT
CONNECTION += port=$(PG_PORT)
PSQLFLAGS += -p $(PG_PORT)
endif

ifdef PG_USER
CONNECTION += user=$(PG_USER)
PSQLFLAGS += -U $(PG_USER)
endif

ifdef PG_PASSWORD
CONNECTION += password=$(PG_PASSWORD)
endif

PSQL = psql $(PSQLFLAGS)

scrape: ; $(PYTHON) src/scrape.py -d $(CONNECTION) --patterns --positions

init: sql/schema.sql
	$(PSQL) -f $<
