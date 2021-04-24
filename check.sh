#!/usr/bin/env bash

set -e
set -a

source .env

# Source additional env files
for env_file in "$@"; do
  . "$env_file"
done

set +a

declare WORKDB_TABLES
declare TARGETDB_TABLES

function prepare_db() {
  docker-compose up -d \
    --force-recreate \
    --renew-anon-volumes &>/dev/null

  echo "Docker-compose created"
  expect <<EOF &>/dev/null
set timeout -1

spawn docker-compose logs -f
expect "flyway exited with code 0"
EOF
  echo "Flyway completed"
}

function table_query_for_schema() {
  echo "SELECT CONCAT(tablename) FROM pg_tables WHERE schemaname='$1' AND tablename NOT LIKE 'flyway%' order by tablename;"
}

function exec_work_db_query() {
  docker exec -i work_db psql -qAt -U "${WORKDB_USER}" "${WORKDB_DB}" <<<"$1"
}

function exec_target_db_query() {
  docker exec -i work_db psql -qAt "sslmode=${TARGETDB_SSLMODE} host=${TARGETDB_HOST} port=${TARGETDB_PORT} dbname=${TARGETDB_DB} user=${TARGETDB_USER} password=${TARGETDB_PASSWORD}" <<<"$1"
}

function get_tables_from_workdb() {
  local table_query
  table_query=$(table_query_for_schema "${WORKDB_SCHEMA}")
  WORKDB_TABLES=$(exec_work_db_query "$table_query")
  echo "Got tables from work db: ${WORKDB_TABLES}"
}

function get_tables_from_target() {
  local table_query
  table_query=$(table_query_for_schema "${TARGETDB_SCHEMA}")
  TARGETDB_TABLES=$(exec_target_db_query "$table_query")
  echo "Got tables from target db: ${TARGETDB_TABLES}"
}

function compare_table_lists() {
  local missing_from_targetdb
  local missing_from_workdb

  missing_from_targetdb=$(comm -23 <(echo "$WORKDB_TABLES") <(echo "$TARGETDB_TABLES"))
  if [ "$missing_from_targetdb" ]; then
    echo "Found tables that are missing from target db: $missing_from_targetdb"
    exit 1
  fi

  missing_from_workdb=$(comm -13 <(echo "$WORKDB_TABLES") <(echo "$TARGETDB_TABLES"))
  if [ "$missing_from_workdb" ]; then
    echo "Found tables that are missing from work db: $missing_from_workdb"
    exit 1
  fi
  echo "Lists of tables match."
}

function compare_table() {
  local workdb_table
  local targetdb_table
  local missing_from_targetdb
  local missing_from_workdb
  echo "Comparing table $1"
  workdb_table=$(exec_work_db_query "\d ${WORKDB_SCHEMA}.$1")
  targetdb_table=$(exec_target_db_query "\d ${TARGETDB_SCHEMA}.$1" | sed "s/${TARGETDB_SCHEMA}/${WORKDB_SCHEMA}/g")
  missing_from_targetdb=$(comm -23 <(echo "$workdb_table") <(echo "$targetdb_table"))
  if [ "$missing_from_targetdb" ]; then
    echo "Found lines that are missing from target db: $missing_from_targetdb"
    exit 1
  fi

  missing_from_workdb=$(comm -13 <(echo "$workdb_table") <(echo "$targetdb_table"))
  if [ "$missing_from_workdb" ]; then
    echo "Found lines that are missing from work db: $missing_from_workdb"
    exit 1
  fi
  echo "Tables match."
}

function compare_tables() {
  for table in $WORKDB_TABLES; do
    compare_table "$table"
  done
}

prepare_db
get_tables_from_workdb
get_tables_from_target
compare_table_lists
compare_tables