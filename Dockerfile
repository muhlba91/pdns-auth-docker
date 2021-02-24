# base image
FROM alpine:3.9 as base

ENV REFRESHED_AT="2021-02-24" \
    POWERDNS_VERSION="4.4.1" \
    BUILD_DEPS="g++ make postgresql-dev curl boost-dev" \
    RUN_DEPS="bash libpq libstdc++ libgcc postgresql-client lua-dev curl-dev boost-program_options" \
    POWERDNS_MODULES="bind gpgsql"


# builder
FROM base AS build

RUN apk --update add $BUILD_DEPS $RUN_DEPS
RUN curl -sSL https://downloads.powerdns.com/releases/pdns-$POWERDNS_VERSION.tar.bz2 | tar xj -C /tmp/
WORKDIR /tmp/pdns-$POWERDNS_VERSION
RUN ./configure --prefix="" --exec-prefix=/usr --sysconfdir=/etc/pdns --with-modules="$POWERDNS_MODULES"
RUN make
RUN DESTDIR="/pdnsbuild" make install-strip
RUN mkdir -p /pdnsbuild/etc/pdns/conf.d /pdnsbuild/etc/pdns/sql
RUN cp modules/gpgsqlbackend/*.sql /pdnsbuild/etc/pdns/sql/


# final image
FROM base

# labels
LABEL maintainer "Daniel Muehlbachler-Pietrzykowski daniel.muehlbachler@niftyside.com"
LABEL name "PowerDNS with PostgreSQL backend"

COPY --from=build /pdnsbuild /
RUN apk add $RUN_DEPS && \
    addgroup -S pdns 2>/dev/null && \
    adduser -S -D -H -h /var/empty -s /bin/false -G pdns -g pdns pdns 2>/dev/null && \
    rm /var/cache/apk/*

ADD assets/pdns.conf /etc/pdns/
ADD assets/entrypoint.sh /bin/powerdns

ENV PGSQL_HOST="postgres" \
    PGSQL_PORT="5432" \
    PGSQL_USER="postgres" \
    PGSQL_PASS="postgres" \
    PGSQL_DB="pdns" \
    PGSQL_VERSION="4.4.1" \
    SCHEMA_VERSION_TABLE="_schema_version"

EXPOSE 53/tcp 53/udp
ENTRYPOINT ["powerdns"]
