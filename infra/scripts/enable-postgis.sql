-- Enable PostGIS on AWS RDS PostgreSQL after the instance is available.
-- Run once via psql, ECS migration task, or CI deploy hook.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
