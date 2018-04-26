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
DATE = 2018-01-01
YEAR = $(shell echo $(DATE) | sed 's/\(.\{4\}\)-.*/\1/')
MONTH =	$(shell echo $(DATE) | sed 's/.\{4\}-\(.\{2\}\)-.*/\1/')

.PHONY: gcloud s3

scrape: ; $(PYTHON) src/scrape.py -d "$(CONNECTION)" --patterns --positions

s3: $(YEAR)/$(MONTH)/$(DATE)-positions.csv.xz $(YEAR)/$(MONTH)/$(DATE)-patterns.csv.xz $(YEAR)/$(MONTH)/$(DATE)-patternstops.csv.xz
	for f in $(^F); do aws s3 cp --quiet --acl public-read $(<F)/$$f s3://$(BUCKET) ; done

gcloud: $(YEAR)/$(MONTH)/$(DATE)-positions.csv.xz
	gsutil cp -rna public-read $< gs://$(BUCKET)/$<

$(YEAR)/$(MONTH)/$(DATE)-patterns.csv.xz $(YEAR)/$(MONTH)/$(DATE)-positions.csv.xz: $(YEAR)/$(MONTH)/$(DATE)-%.csv.xz: | $(YEAR)/$(MONTH)
	$(PSQL) -c "COPY (\
		SELECT * FROM cta.$* WHERE timestamp::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

$(YEAR)/$(MONTH)/$(DATE)-pattern_stops.csv.xz: | $(YEAR)/$(MONTH)
	$(PSQL) -c "COPY (\
		SELECT a.* FROM cta.pattern_stops a INNER JOIN cta.patterns USING (pid) \
		WHERE timestamp::date = '$(DATE)'::date \
		) TO STDOUT WITH (FORMAT CSV, HEADER true)" | \
	xz -z - > $@

$(YEAR)/$(MONTH):
	mkdir -p $@

clean-date:
	$(PSQL) -c "DELETE FROM cta.positions where timestamp::date = '$(DATE)'::date"
	rm -f $(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv{.xz,}

init: sql/schema.sql requirements.txt
	$(PYTHON) -m pip install -r $(filter %.txt,$^)
	$(PSQL) -f $<
