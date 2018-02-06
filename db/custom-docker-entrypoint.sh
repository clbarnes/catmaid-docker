#!/bin/bash

DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_CONNECTIONS=${DB_CONNECTIONS:-50}
DB_CONF_FILE=${DB_CONF_FILE:-"/var/lib/postgresql/data/postgresql.conf"}
DB_FORCE_TUNE=${DB_FORCE_TUNE:-false}
AVAILABLE_MEMORY=`awk '/MemTotal/ { printf "%.3f \n", $2/1024 }' /proc/meminfo`
INSTANCE_MEMORY=${INSTANCE_MEMORY:-$AVAILABLE_MEMORY}

tune_db () {
  echo "Wait until database $DB_HOST:$DB_PORT is ready..."
  until nc -z $DB_HOST $DB_PORT
  do
      sleep 1
  done

  # Wait to avoid "panic: Failed to open sql connection pq: the database system is starting up"
  sleep 1

  echo "Tuning Postgres server configuration (connections: $DB_CONNECTIONS memory: $INSTANCE_MEMORY MB force: $DB_FORCE_TUNE)"
  INSTANCE_MEMORY=${INSTANCE_MEMORY} CONNECTIONS=${DB_CONNECTIONS} CONF_FILE=${DB_CONF_FILE} FORCE_PGTUNE=${DB_FORCE_TUNE} python /pg_tune.py
  service postgresql reload
}

tune_db &
. /docker-entrypoint.sh postgres
