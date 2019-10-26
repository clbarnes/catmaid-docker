#!/bin/bash

DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_CONNECTIONS=${DB_CONNECTIONS:-50}
DB_CONF_FILE=${DB_CONF_FILE:-"/var/lib/postgresql/data/postgresql.conf"}
DB_FORCE_TUNE=${DB_FORCE_TUNE:-false}
DB_TUNE=${DB_TUNE:-true}
DB_UPDATE=${DB_UPDATE:-false}
AVAILABLE_MEMORY=`awk '/MemTotal/ { printf "%.3f \n", $2/1024 }' /proc/meminfo`
INSTANCE_MEMORY=${INSTANCE_MEMORY:-$AVAILABLE_MEMORY}
DATA_PG_VERSION=$(cat /var/lib/postgresql/data/PG_VERSION)
BIN_PG_VERSION="12"
DB_POSTGIS_VERSION="3"
DB_SUPERUSER=${POSTGRES_USER:-postgres}
PG_BIN="/usr/lib/postgresql/${BIN_PG_VERSION}/bin"


# Make sure we have a Postgres superuser role called "postgres".
check_db_superuser() {
  # Allow custom path and port as parameters
  PG_PATH=${1:-$PG_BIN}
  PG_PORT=${2:-$DB_PORT}

  if su postgres -c "${PG_PATH}/psql -U ${DB_SUPERUSER} -p ${PG_PORT} -t -c '\du' | cut -d \| -f 1 | grep -qw postgres"; then
    echo "- PostgreSQL superuser postgres found"
  else
    echo "- No PostgreSQL superuser found, adding user account postgres"
    su postgres -c "${PG_PATH}/createuser -U ${DB_SUPERUSER} -p ${PG_PORT} -s postgres"
  fi
}

stop_postgres() {
  if [ -f "/var/lib/postgresql/data/postmaster.pid" ]; then
    if [ -f "/proc/$(cat /var/lib/postgresql/data/postmaster.pid)/status" ]; then
      echo "- Stopping currently running postmaster"
      su postgres -c "/usr/lib/postgresql/${BIN_PG_VERSION}/bin/pg_ctl -D /var/lib/postgresql/data/ stop"
    else
      echo "- Removing stale postmaster.pid file"
      rm /var/lib/postgresql/data/postmaster.pid
    fi
  fi
}

tune_db() {
  echo "Wait until database $DB_HOST:$DB_PORT is ready..."
  until su postgres -c "${PG_BIN}/pg_isready -h ${DB_HOST} -p ${DB_PORT} -q; exit \$?"
  do
      sleep 1
  done

  # Wait to avoid "panic: Failed to open sql connection pq: the database system is starting up"
  sleep 1

  if [ "$DB_TUNE" = true ] ; then
    echo "Tuning Postgres server configuration (connections: $DB_CONNECTIONS memory: $INSTANCE_MEMORY MB force: $DB_FORCE_TUNE)"
    INSTANCE_MEMORY=${INSTANCE_MEMORY} CONNECTIONS=${DB_CONNECTIONS} CONF_FILE=${DB_CONF_FILE} FORCE_PGTUNE=${DB_FORCE_TUNE} python /pg_tune.py
    su postgres -c "${PG_BIN}/pg_ctl -D /var/lib/postgresql/data/ reload -w; exit \$?"
  fi
}

# Copied from the base image's Dockerfile to install or compile a specific
# Postgres version.
install_postgres() {
  PG_MAJOR=$1
  set -e; \
    \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "$dpkgArch" in \
      amd64|i386|ppc64el) \
  # arches officialy built by upstream
        echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main $PG_MAJOR" > /etc/apt/sources.list.d/pgdg.list; \
        apt-get update; \
        ;; \
      *) \
  # we're on an architecture upstream doesn't officially build for
  # let's build binaries from their published source packages
        echo "deb-src http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main $PG_MAJOR" > /etc/apt/sources.list.d/pgdg.list; \
        \
        tempDir="$(mktemp -d)"; \
        cd "$tempDir"; \
        \
        savedAptMark="$(apt-mark showmanual)"; \
        \
  # build .deb files from upstream's source packages (which are verified by apt-get)
        apt-get update; \
        apt-get build-dep -y \
          postgresql-common pgdg-keyring \
          "postgresql-$PG_MAJOR" \
        ; \
        DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" \
          apt-get source --compile \
            postgresql-common pgdg-keyring \
            "postgresql-$PG_MAJOR" \
        ; \
  # we don't remove APT lists here because they get re-downloaded and removed later
        \
  # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
  # (which is done after we install the built packages so we don't have to redownload any overlapping dependencies)
        apt-mark showmanual | xargs apt-mark auto > /dev/null; \
        apt-mark manual $savedAptMark; \
        \
  # create a temporary local APT repo to install from (so that dependency resolution can be handled by APT, as it should be)
        ls -lAFh; \
        dpkg-scanpackages . > Packages; \
        grep '^Package: ' Packages; \
        echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list; \
  # work around the following APT issue by using "Acquire::GzipIndexes=false" (overriding "/etc/apt/apt.conf.d/docker-gzip-indexes")
  #   Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
  #   ...
  #   E: Failed to fetch store:/var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages  Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
        apt-get -o Acquire::GzipIndexes=false update; \
        ;; \
    esac; \
    \
    apt-get install -y --no-install-recommends postgresql-common; \
    sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf; \
    apt-get install -y --no-install-recommends \
      "postgresql-$PG_MAJOR" \
    ; \
    \
    rm -rf /var/lib/apt/lists/*; \
    \
    if [ -n "$tempDir" ]; then \
  # if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
      apt-get purge -y --auto-remove; \
      rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
    fi
}

update_postgres () {
  echo "Upgrading Postgres installation"

  # Needed to make sure the container APT cache is initialized
  apt-get update

  echo "- Installing binaries for Postgres $DATA_PG_VERSION to read existing data"
  install_postgres ${DATA_PG_VERSION}
  apt-get clean
  apt-get update

  apt-get install -y --no-install-recommends liblwgeom-dev tzdata
  apt-get install -y --no-install-recommends "postgresql-$DATA_PG_VERSION-postgis-$DB_POSTGIS_VERSION" "postgresql-$DATA_PG_VERSION-postgis-$DB_POSTGIS_VERSION-scripts"

  echo "- Ensuring correct permissions for Postgres data directory"
  chown -R postgres:postgres /var/lib/postgresql/data

  stop_postgres

  # Start the old database version
  PGBIN_OLD="/usr/lib/postgresql/${DATA_PG_VERSION}/bin"
  echo "- Wait until old version database localhost:5433 is ready..."
  su postgres -c "${PGBIN_OLD}/pg_ctl -D /var/lib/postgresql/data/ start -w -o \"-p 5433 \""
  until su postgres -c "${PGBIN_OLD}/pg_isready -h localhost -p 5433 -q; exit \$?"
  do
      sleep 1
  done

  # Make sure there is a Postgres superuser
  check_db_superuser $PGBIN_OLD 5433

  # Upgrade PostGIS
  echo "- Preparing PostGIS migration"
  # get list of databases in system , exclude the tempate dbs
  PSQL_OLD="${PGBIN_OLD}/psql -p 5433"
  DBS=( $(su postgres -c "${PSQL_OLD} -t -A -c \"select datname from pg_database where datname not in ('template0', 'template1')\"") )
  # Updating the PostGIS version in the "old" data, makes upgrading easier.
  for database in "${DBS[@]}" ; do
    echo "  Updating PostGIS version in database ${database}"
    echo "  Messages like \"ERROR: extension ... does not exist\" can be ignored."
    su postgres -c "${PSQL_OLD} -d ${database} -c \"ALTER EXTENSION postgis UPDATE;\" >> /dev/null; exit 0"
    su postgres -c "${PSQL_OLD} -d ${database} -c \"ALTER EXTENSION postgis_topology UPDATE;\" >> /dev/null; exit 0"
    su postgres -c "${PSQL_OLD} -d ${database} -c \"ALTER EXTENSION postgis_tiger_geocoder UPDATE;\" >> /dev/null; exit 0"
  done

  # The original install user is needed for pg_upgrade
  PG_INSTALL_USER=`su postgres -c 'psql -p 5433 -X -A -t -c "SELECT rolname FROM pg_roles WHERE oid = 10 LIMIT 1"'`
  echo "- Found install user of previous Postgres cluster: ${PG_INSTALL_USER}"

  su postgres -c "/usr/lib/postgresql/${DATA_PG_VERSION}/bin/pg_ctl -D /var/lib/postgresql/data/ stop"

  echo "- Moving old data files into separate directory"
  mkdir -p /var/lib/postgresql/data/old-data
  find /var/lib/postgresql/data ! -regex '.*/old-data' ! -regex '^/var/lib/postgresql/data$' -maxdepth 1 -exec mv '{}' /var/lib/postgresql/data/old-data \;
  chown -R postgres:postgres /var/lib/postgresql/data/old-data
  chmod 0700 /var/lib/postgresql/data/old-data

  echo "- Creating new Postgres $BIN_PG_VERSION data directory using original install user $PG_INSTALL_USER"
  mkdir -p /var/lib/postgresql/data/new-data
  chown postgres:postgres /var/lib/postgresql/data/new-data
  chmod 0700 /var/lib/postgresql/data/new-data
  su postgres -c "/usr/lib/postgresql/${BIN_PG_VERSION}/bin/initdb -E 'UTF8' -U ${PG_INSTALL_USER} -D /var/lib/postgresql/data/new-data" -

  echo "- Copying previous postgres configuration"
  cp /var/lib/postgresql/data/new-data/postgresql.conf /var/lib/postgresql/data/new-data/postgresql.conf.original
  cp /var/lib/postgresql/data/old-data/postgresql.conf /var/lib/postgresql/data/new-data/postgresql.conf
  cp /var/lib/postgresql/data/new-data/pg_hba.conf /var/lib/postgresql/data/new-data/pg_hba.conf.original
  cp /var/lib/postgresql/data/old-data/pg_hba.conf /var/lib/postgresql/data/new-data/pg_hba.conf
  chown -R postgres:postgres /var/lib/postgresql/data/new-data

  echo "- Upgrading Postgres data to version $BIN_PG_VERSION"
  echo "- Executed command line: cd /var/lib/postgresql/data/; /usr/lib/postgresql/${BIN_PG_VERSION}/bin/pg_upgrade-b '/usr/lib/postgresql/${DATA_PG_VERSION}/bin/' -B '/usr/lib/postgresql/${BIN_PG_VERSION}/bin/' -d '/var/lib/postgresql/data/old-data/' -D '/var/lib/postgresql/data/new-data/' -k -p 5433 -P 5434 -U ${PG_INSTALL_USER}"
  su postgres -c "cd /var/lib/postgresql/data/; /usr/lib/postgresql/${BIN_PG_VERSION}/bin/pg_upgrade -b '/usr/lib/postgresql/${DATA_PG_VERSION}/bin/' -B '/usr/lib/postgresql/${BIN_PG_VERSION}/bin/' -d '/var/lib/postgresql/data/old-data/' -D '/var/lib/postgresql/data/new-data' -k -p 5433 -P 5434 -U ${PG_INSTALL_USER}"

  echo "- Uninstalling old Postgres $DATA_PG_VERSION binaries"
  apt-get remove -y "postgresql-$DATA_PG_VERSION" "postgresql-$DATA_PG_VERSION-postgis-$DB_POSTGIS_VERSION"
  apt-get autoremove -y

  echo "- Move Postgres data directories into right place"
  rm -r /var/lib/postgresql/data/old-data
  find /var/lib/postgresql/data/new-data ! -regex '^/var/lib/postgresql/data/new-data$' -maxdepth 1 -exec mv '{}' /var/lib/postgresql/data \;
  rm -r /var/lib/postgresql/data/new-data

  echo "- Analyzing upgraded database"
  PGBIN_NEW="/usr/lib/postgresql/${BIN_PG_VERSION}/bin"
  su postgres -c "${PGBIN_NEW}/pg_ctl -D /var/lib/postgresql/data/ start -w -o \"-p 5433 \""
  su postgres -c "${PGBIN_NEW}/vacuumdb -p 5433 --all --analyze-only"
  su postgres -c "${PGBIN_NEW}/pg_ctl -D /var/lib/postgresql/data/ stop -w"

  # Update paths in postgres configuration files
  echo "- Updating Postgres data path in configuration files"
  sed -i -e 's/\/new-data//g' /var/lib/postgresql/data/postgresql.conf
  sed -i -e "s/^timezone =.*$/timezone = 'UTC'/g" /var/lib/postgresql/data/postgresql.conf
}

# If the current Postgres version is different from the data files, ask user if
# data files should be upgraded.
if [ "$DATA_PG_VERSION" != "" ] ; then
  if [ "$DATA_PG_VERSION" != "$BIN_PG_VERSION" ] ; then
      printf "Warning: Postgres was updated to version $BIN_PG_VERSION and the\n\
existing data files of version $DATA_PG_VERSION need to be updated\n\
to match it.\n"

      if [ "$DB_UPDATE" = true ] ; then
        update_postgres
      else
        printf "Aborting container start, database update needed. To allow\n\
automatic database updates, please backup your database and\n\
set \"DB_UPDATE=true\" in the docker-compose.yml file. To\n\
backup your database, create a copy of the \"volumes\" folder\n\
after the container has stopped:\n\nsudo cp -r volumes volumes.backup\n\n"
        stop_postgres
        exit 1
      fi
  else
      if [ "$DB_UPDATE" = true ] ; then
        printf "Warning: the DB_UPDATE environment variable is set true even\n\
though no update is needed. To avoid automatic updates without\n\
taking a backup beforehand, set DB_UPDATE=false in your\n\
docker-compose.yml file.\n"
      fi
  fi
fi

check_db_superuser &
tune_db &
. /docker-entrypoint.sh postgres
