# PowerDNS Docker Container

[![Build Status](https://travis-ci.org/muhlba91/pdns-auth-docker.svg?branch=master)](https://travis-ci.org/muhlba91/pdns-auth-docker)

Taken and modified from [naps/docker-powerdns](https://github.com/naps/docker-powerdns) to support only:

* Small Alpine based Image
* Postgres backend with auto migration
* Guardian process enabled
* Graceful shutdown using pdns_control

## Usage

```shell
# Start a Postgres Container
$ docker run -d \
  --name pdns-postgres \
  -e POSTGRES_PASSWORD=supersecret \
  -v $PWD/postgres-data:/var/lib/postgresql \
  postgres:9.6

$ docker run --name pdns \
  --link pdns-postgres:postgres \
  -p 53:53 \
  -p 53:53/udp \
  -e PGSQL_USER=postgres \
  -e PGSQL_PASS=supersecret \
  naps/powerdns \
    --cache-ttl=120 \
    --allow-axfr-ips=127.0.0.1,123.1.2.3
```

## Configuration

**Environment Configuration:**

* Postgres connection settings
  * `PGSQL_HOST=psql`
  * `PGSQL_USER=root`
  * `PGSQL_PASS=root`
  * `PGSQL_DB=pdns`
* DNSSEC is disabled by default, to enable use `DNSSEC=yes`
* Want to apply 12Factor-Pattern? Apply environment variables of the form `PDNS_$pdns-config-variable=$config-value`, like `PDNS_WEBSERVER=yes`
* Want to use own config files? Mount a Volume to `/etc/pdns/conf.d` or simply overwrite `/etc/pdns/pdns.conf`
* Use `TRACE=true` to debug the pdns config directives

**PowerDNS Configuration:**

Append the PowerDNS setting to the command as shown in the example above.
See `docker run --rm muhlba91/powerdns --help`

## Contributions

Submit an issue describing the problem(s)/question(s) and proposed fixes/work-arounds.

To contribute, just fork the repository, develop and test your code changes and submit a pull request.