shell = bash

PYTHON = python

PGHOST ?=
PGPORT ?=
PGUSER ?= $(USER)
PGDATABASE ?= $(PGUSER)
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

PSQL = psql $(PSQLFLAGS)

BUCKET = chibus

.PHONY: gcloud s3

scrape: ; $(PYTHON) src/scrape.py -d "$(CONNECTION)" --patterns --positions

s3: $(PREFIX)/$(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz
	aws s3 cp --quiet --acl public-read $< s3://$(BUCKET)

gcloud: $(PREFIX)/$(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz
	gsutil cp -rna public-read $< gs://$(BUCKET)/$<

$(PREFIX)/$(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv.xz: | $(PREFIX)/$(YEAR)/$(MONTH)
	$(PSQL) -c "COPY (\
		SELECT * FROM rt_vehicle_positions WHERE timestamp::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

clean-date:
	$(PSQL) -c "DELETE FROM rt_vehicle_positions where timestamp::date = '$(DATE)'::date"
	rm -f $(PREFIX)/$(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv{.xz,}


init: sql/schema.sql requirements.txt
	$(PYTHON) -m pip install -r $(filter %.txt,$^)
	$(PSQL) -f $<
