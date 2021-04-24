# flyway-history-rewrite-check

Helper script for checking if Flyway history of a postgres-database can be rewritten.

The script runs flyway migrations from `${MIGRATION_DIRECTORY}` to work db, 
and checks if the work databases table definitions match the ones in target database.

If all definitions match, it should be safe to overwrite `flyway_schema_history` with the one created in work db.

Use at your own risk.

Script can be tested by executing `./test.sh`

## Prerequisites
- Docker
- Docker-compose
- expect

## Usage:
- Create a new env-file with details of target database, take example from `.env.test`
- Execute `./check.sh [env-file]`
