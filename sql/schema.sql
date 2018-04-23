CREATE SCHEMA IF NOT EXISTS cta;

CREATE TABLE IF NOT EXISTS cta.positions (
    "timestamp" timestamp with time zone NOT NULL,
    "vehicle_id" text NOT NULL,
    "latitude" numeric(9,6),
    "longitude" numeric(9,6),
    "bearing" numeric(5,2),
    "pattern_id" int,
    "route_id" text,
    "destination" text,
    "dist_along_route" numeric,
    "delayed" boolean,
    "trip_id" text,
    "tablockid" text,
    "zone" text,
    CONSTRAINT cta_position_pk PRIMARY KEY ("timestamp", "vehicle_id")
);

CREATE TABLE IF NOT EXISTS cta.pattern_stops (
    "pid" int,
    "stop_sequence" int,
    "stop_id" int default 0,
    "stop_name" text,
    "pdist" numeric,
    "latitude" numeric(9,6),
    "longitude" numeric(9,6),
    "type" text,
    CONSTRAINT cta_pattern_stops_pk PRIMARY KEY ("pid", "stop_sequence")
);

CREATE TABLE IF NOT EXISTS cta.patterns (
    "pid" int PRIMARY KEY,
    "length" numeric,
    "route_direction" text,
    "timestamp" timestamp default current_timestamp
);
