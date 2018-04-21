shell = bash

PYTHON = python

PGHOST ?=
PGPORT ?=
PGUSER ?=
PGDATABASE ?=
PSQLFLAGS = $(PGDATABASE)

CONNECTION = dbname=$(PGDATABASE)

ifdef PGHOST
CONNECTION += host=$(PGHOST)
PSQLFLAGS += -h $(PGHOST)
endif

ifdef PGPORT
CONNECTION += port=$(PGPORT)
PSQLFLAGS += -p $(PGPORT)
endif

ifdef PGUSER
CONNECTION += user=$(PGUSER)
PSQLFLAGS += -U $(PGUSER)
endif

ifdef PGPASSWORD
CONNECTION += password=$(PGPASSWORD)
endif

PSQL = psql $(PSQLFLAGS)

scrape: ; $(PYTHON) src/scrape.py -d $(CONNECTION) --patterns --positions

init: sql/schema.sql
	$(PSQL) -f $<
