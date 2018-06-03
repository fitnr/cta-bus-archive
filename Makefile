# Copyright 2018 Active Transportation Alliance
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

shell = bash

PYTHON = python

PGUSER ?= $(USER)
PGDATABASE ?= $(PGUSER)
PSQLFLAGS = $(PGDATABASE)
PSQL = psql $(PSQLFLAGS)

export PGDATABASE PGUSER

BUCKET = chibus
DATE = 2018-01-01
YEAR = $(shell echo $(DATE) | sed 's/\(.\{4\}\)-.*/\1/')
MONTH =	$(shell echo $(DATE) | sed 's/.\{4\}-\(.\{2\}\)-.*/\1/')

.PHONY: gcloud s3 s3-positions s3-patterns s3-pattern_stops

# Relies on environment variables being set
scrape: ; $(PYTHON) src/scrape.py --patterns --positions

s3: s3-positions s3-patterns s3-pattern_stops

s3-positions s3-patterns s3-pattern_stops: s3-%: $(YEAR)/$(MONTH)/$(DATE)-%.csv.xz
	aws s3 cp --quiet --acl public-read $< s3://$(BUCKET)/$<

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
	$(PSQL) -c "DELETE FROM cta.pattern_stops using cta.patterns p \
		where pattern_stops.pid = p.pid and timestamp::date = '$(DATE)'::date"
	$(PSQL) -c "DELETE FROM cta.patterns where timestamp::date = '$(DATE)'::date"
	rm -f $(YEAR)/$(MONTH)/$(DATE)-bus-positions.csv{.xz,}

init: sql/schema.sql requirements.txt
	$(PYTHON) -m pip install -r $(filter %.txt,$^)
	$(PSQL) -f $<
