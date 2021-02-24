#!/bin/bash
set -e

[[ -z "$TRACE" ]] || set -x

# --help, --version
[ "$1" = "--help" ] || [ "$1" = "--version" ] && exec pdns_server $1

# treat everything except -- as exec cmd
[ "${1:0:2}" != "--" ] && exec "$@"

# Set credentials to be imported into pdns.conf
export PDNS_LOAD_MODULES=$PDNS_LOAD_MODULES,libgpgsqlbackend.so
export PDNS_GPGSQL_HOST=${PDNS_GPGSQL_HOST:-$PGSQL_HOST}
export PDNS_GPGSQL_PORT=${PDNS_GPGSQL_PORT:-$PGSQL_PORT}
export PDNS_GPGSQL_USER=${PDNS_GPGSQL_USER:-$PGSQL_USER}
export PDNS_GPGSQL_PASSWORD=${PDNS_GPGSQL_PASSWORD:-$PGSQL_PASS}
export PDNS_GPGSQL_DBNAME=${PDNS_GPGSQL_DBNAME:-$PGSQL_DB}
export PDNS_GPGSQL_DNSSEC=${PDNS_GPGSQL_DNSSEC:-$DNSSEC}
export PGPASSWORD=$PDNS_GPGSQL_PASSWORD

PGSQLCMD="psql --host=$PGSQL_HOST --username=$PGSQL_USER"

# wait for Database come ready
isDBup () {
  echo "SELECT 1" | $PGSQLCMD 1>/dev/null
}

RETRY=10
until [ `isDBup` -eq 0 ] || [ $RETRY -le 0 ] ; do
  echo "Waiting for database to come up"
  sleep 5
  RETRY=$(expr $RETRY - 1)
done
if [ $RETRY -le 0 ]; then
  >&2 echo Error: Could not connect to Database on $PGSQL_HOST:$PGSQL_PORT
  exit 1
fi

# init database and migrate database if necessary
if [[ -z "$(echo "SELECT 1 FROM pg_database WHERE datname = '$PGSQL_DB'" | $PGSQLCMD -t)" ]]; then
  echo "CREATE DATABASE $PGSQL_DB;" | $PGSQLCMD
fi
PGSQLCMD="$PGSQLCMD $PGSQL_DB"
if [[ -z "$(printf '\dt' | $PGSQLCMD -qAt)" ]]; then
  echo Initializing Database
  cat /usr/share/doc/pdns/schema.pgsql.sql | $PGSQLCMD
  INITIAL_DB_VERSION=$PGSQL_VERSION
fi
# init version database if necessary
if [[ -z "$(echo "SELECT to_regclass('public.$SCHEMA_VERSION_TABLE');" | $PGSQLCMD -qAt)" ]]; then
  [ -z "$INITIAL_DB_VERSION" ] && >&2 echo "Error: INITIAL_DB_VERSION is required the first time" && exit 1
  echo "CREATE TABLE $SCHEMA_VERSION_TABLE (id SERIAL PRIMARY KEY, version VARCHAR(255) DEFAULT NULL)" | $PGSQLCMD
  echo "INSERT INTO $SCHEMA_VERSION_TABLE (version) VALUES ('$INITIAL_DB_VERSION');" | $PGSQLCMD
  echo "Initialized schema version to $INITIAL_DB_VERSION"
fi
# do the database upgrade
while true; do
  current="$(echo "SELECT version FROM $SCHEMA_VERSION_TABLE ORDER BY id DESC LIMIT 1;" | $PGSQLCMD -qAt)"
  if [ "$current" != "$PGSQL_VERSION" ]; then
    filename=/usr/share/doc/pdns/${current}_to_*_schema.pgsql.sql
    echo "Applying Update $(basename $filename)"
    $PGSQLCMD < $filename
    current=$(basename $filename | sed -n 's/^[0-9.]\+_to_\([0-9.]\+\)_.*$/\1/p')
    echo "INSERT INTO $SCHEMA_VERSION_TABLE (version) VALUES ('$current');" | $PGSQLCMD
  else
    break
  fi
done

# convert all environment variables prefixed with PDNS_ into pdns config directives
PDNS_LOAD_MODULES="$(echo $PDNS_LOAD_MODULES | sed 's/^,//')"
printenv | grep ^PDNS_ | cut -f2- -d_ | while read var; do
  val="${var#*=}"
  var="${var%%=*}"
  var="$(echo $var | sed -e 's/_/-/g' | tr '[:upper:]' '[:lower:]')"
  [[ -z "$TRACE" ]] || echo "$var=$val"
  (grep -qE "^[# ]*$var=.*" /etc/pdns/pdns.conf && sed -r -i "s#^[# ]*$var=.*#$var=$val#g" /etc/pdns/pdns.conf) || echo "$var=$val" >> /etc/pdns/pdns.conf
done

# environment hygiene
for var in $(printenv | cut -f1 -d= | grep -v -e HOME -e USER -e PATH ); do unset $var; done
export TZ=UTC LANG=C LC_ALL=C

# prepare graceful shutdown
trap "pdns_control quit" SIGHUP SIGINT SIGTERM

# run the server
pdns_server "$@" &

wait
