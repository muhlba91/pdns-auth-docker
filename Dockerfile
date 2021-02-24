# basic container
FROM alpine:3.12

# labels
LABEL maintainer "Daniel Muehlbachler-Pietrzykowski daniel.muehlbachler@niftyside.com"
LABEL name "PowerDNS with PostgreSQL backend"

# config
ENV POWERDNS_VERSION "4.2.3-r0"

# install pdns
RUN apk update \
  && apk add --no-cache \
    wget  \
    git \
    make \
    bash \
    pdns=$POWERDNS_VERSION \
    pdns-backend-pgsql=$POWERDNS_VERSION \
    pdns-doc=$POWERDNS_VERSION \
    pdns-tools=$POWERDNS_VERSION \
  && rm -rf /var/cache/apk/*

# assets
ADD assets/pdns.conf /etc/pdns/
ADD assets/entrypoint.sh /bin/powerdns

# environment
ENV PGSQL_HOST="postgres" \
    PGSQL_PORT="5432" \
    PGSQL_USER="postgres" \
    PGSQL_PASS="postgres" \
    PGSQL_DB="pdns" \
    PGSQL_VERSION="4.2.0" \
    SCHEMA_VERSION_TABLE="_schema_version"

# expose and entrypoint
EXPOSE 53/tcp 53/udp
ENTRYPOINT ["powerdns"]
