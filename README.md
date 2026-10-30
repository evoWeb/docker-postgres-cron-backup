# postgres-cron-backup

## Base on the work of [Javier Delgado](https://github.com/fradelg/docker-mysql-cron-backup)

Run pg_dump to back up your databases periodically using the cron task manager in the container. Your backups are saved in `/backup`. You can mount any directory of your host or a docker volumes in /backup. Otherwise, a docker volume is created in the default location.


## Usage:

```bash
docker container run -d \
       --env POSTGRES_HOST=my_postgres \
       --env POSTGRES_USER=postgres \
       --env POSTGRES_PASSWORD=my_password \
       --network my_network \
       --volume /path/to/my/backup/folder:/backup \
       evoweb/postgres-cron-backup:18
```

Use the image tag matching the major version of your PostgreSQL server (`16`, `17` or `18`), so `pg_dump` and `psql` are compatible with it.


### Healthcheck

Container is **Healthy** after the database init phase, that is after `INIT_BACKUP` or `INIT_RESTORE_LATEST` happened, **Starting** otherwise.
It turns **Unhealthy** within three minutes when a backup fails, and healthy again with the next successful backup.

A backup fails when no database is found or when `pg_dump` or `gzip` exits with an error. In that case `backup.sh` exits with a non-zero code, removes the incomplete dump and keeps all existing backups, so `MAX_BACKUPS` never rotates out a good backup in favor of a broken one.


## Variables

- `POSTGRES_HOST`: The host/ip of your postgres database. Default: `postgres`.
- `POSTGRES_HOST_FILE`: The file in container where to find the host of your postgres database (cf. docker secrets). You should use either POSTGRES_HOST_FILE or POSTGRES_HOST (see examples below).
- `POSTGRES_PORT`: The port number of your postgres database. Default: `5432`.
- `POSTGRES_USER`: The username of your postgres database.
- `POSTGRES_USER_FILE`: The file in container where to find the user of your postgres database (cf. docker secrets). You should use either POSTGRES_USER_FILE or POSTGRES_USER (see examples below).
- `POSTGRES_PASSWORD`: The password of your postgres database.
- `POSTGRES_PASSWORD_FILE`: The file in container where to find the password of your postgres database (cf. docker secrets). You should use either POSTGRES_PASSWORD_FILE or POSTGRES_PASSWORD (see examples below).
- `POSTGRES_DB`: The database name to dump. Default: all databases except `postgres` and the templates.
- `POSTGRES_DB_FILE`: The file in container where to find the database name(s) in your postgres database (cf. docker secrets). In that file, there can be several database names: one per line. You should use either POSTGRES_DB or POSTGRES_DB_FILE (see examples below).
- `PG_DUMP_OPTS`: Command line arguments to pass to pg_dump (see [pg_dump documentation](https://www.postgresql.org/docs/current/app-pgdump.html)). Default: `--rows-per-insert=1`.
- `PSQL_SSL_OPTS`: Command line arguments to use [SSL](https://www.postgresql.org/docs/current/ssl-tcp.html).
- `CRON_TIME`: The interval of cron job to run pg_dump. `0 3 * * sun` by default, which is every Sunday at 03:00. It uses UTC timezone.
- `MAX_BACKUPS`: The number of backups to keep per database. When reaching the limit, the oldest backup of that database will be discarded. No limit by default.
- `INIT_BACKUP`: If set to `1`, create a backup when the container starts. `0` disables it.
- `INIT_RESTORE_LATEST`: If set, restores latest backup.
- `EXIT_BACKUP`: If set, create a backup when the container stops.
- `TIMEOUT`: How long to wait on startup for the database port to be reachable, `10s` by default. If the database is not reachable within that time, the container exits with an error and is restarted according to its restart policy.
- `GZIP_LEVEL`: Specify the level of gzip compression from 1 (quickest, least compressed) to 9 (slowest, most compressed), default is 6.
- `USE_PLAIN_SQL`: If set, back up and restore plain SQL files without gzip.
- `TZ`: Specify TIMEZONE in Container. E.g. "Europe/Berlin". Default is UTC.

If you want to make this image the perfect companion of your Postgres container,
use [docker-compose](https://docs.docker.com/compose/). You can add more services
that will be able to connect to the Postgres image using the service name `postgres`,
note that you only expose the port `5432` internally to the servers and not to the host:


### docker compose with POSTGRES_PASSWORD env var:

```yaml
networks:
    backend:

volumes:
    data:
    backup:
        driver: local
        driver_opts:
            o: bind
            type: none
            device: ${BACKUP_FOLDER:-.}

services:
    postgres:
        image: postgres:18
        expose:
            - 5432
        volumes:
            - data:/var/lib/postgresql
            - backup:/backup
        environment:
            POSTGRES_DB: ${POSTGRES_DB}
            POSTGRES_USER: ${POSTGRES_USER}
            POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
        restart: unless-stopped
        networks:
            - backend

    backup:
        build:
            context: .
            args:
                POSTGRES_VERSION: 18
        depends_on:
            - postgres
        volumes:
            - backup:/backup
            # activate while developing
            #- ./Scripts:/Scripts
        environment:
            POSTGRES_HOST: postgres
            POSTGRES_DB: ${POSTGRES_DB}
            POSTGRES_USER: ${POSTGRES_USER}
            POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
            PG_DUMP_OPTS: --no-tablespaces
            MAX_BACKUPS: 15
            INIT_BACKUP: 0
            CRON_TIME: 0 3 * * *
            GZIP_LEVEL: 9
        restart: unless-stopped
        networks:
            - backend

```


### docker compose using docker secrets:

The database superuser password passed to docker container by using [docker secrets](https://docs.docker.com/engine/swarm/).

In example below, docker is in classic 'docker engine mode' (iow. not swarm mode) and secret sources are local files on host filesystem.

Alternatively, secrets can be stored in docker secrets engine (iow. not in host filesystem).

```yaml
secrets:
    # Place your secret file somewhere on your host filesystem, with your password inside
    postgres_db:
        file: ./secrets/postgres_db
    postgres_user:
        file: ./secrets/postgres_user
    postgres_password:
        file: ./secrets/postgres_password

networks:
    backend:

services:
    postgres:
        image: postgres:18
        container_name: my_postgres
        expose:
            - 5432
        volumes:
            - data:/var/lib/postgresql
            - ${VOLUME_PATH}/backup:/backup
        environment:
            - POSTGRES_DB_FILE=/run/secrets/postgres_db
            - POSTGRES_USER_FILE=/run/secrets/postgres_user
            - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
        secrets:
            - postgres_db
            - postgres_user
            - postgres_password
        restart: unless-stopped
        networks:
            - backend

    backup:
        image: evoweb/postgres-cron-backup:18
        depends_on:
            - postgres
        volumes:
            - ${VOLUME_PATH}/backup:/backup
        environment:
            - POSTGRES_HOST=my_postgres
            - POSTGRES_DB_FILE=/run/secrets/postgres_db
            # Alternatively to POSTGRES_USER_FILE, we can use POSTGRES_USER=postgres to use default user instead
            - POSTGRES_USER_FILE=/run/secrets/postgres_user
            # Alternatively, we can use /run/secrets/postgres_password when using default user
            - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
            - MAX_BACKUPS=10
            - INIT_BACKUP=1
            - CRON_TIME=0 0 * * *
        secrets:
            - postgres_db
            - postgres_user
            - postgres_password
        restart: unless-stopped
        networks:
            - backend

volumes:
    data:
```


## Restore from a backup

### List all available backups :

See the list of backups in your running docker container, just write in your favorite terminal:

```bash
docker container exec <your_postgres_backup_container_name> ls /backup
```


### Restore using a compose file

To restore a database from a certain backup you may have to specify the database name in the variable POSTGRES_DB:

```yaml
services:
    postgres-cron-backup:
        image: evoweb/postgres-cron-backup:18
        command: "/Scripts/restore.sh /backup/201708060500.${DATABASE_NAME}.sql.gz"
        depends_on:
            - postgres
        volumes:
            - ${VOLUME_PATH}/backup:/backup
        environment:
            POSTGRES_HOST: my_postgres
            POSTGRES_DB: ${POSTGRES_DB}
            POSTGRES_USER: ${POSTGRES_USER}
            POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```


### Restore using a docker command

```bash
docker container exec <your_postgres_backup_container_name> /Scripts/restore.sh /backup/<your_sql_backup_gz_file>
```

If no database name is specified, `restore.sh` will try to find the database name from the backup file.


### Automatic backup and restore on container starts and stops

Set `INIT_RESTORE_LATEST` to automatic restore the last backup on startup.
Set `EXIT_BACKUP` to automatically create a last backup on shutdown.

```yaml
services:
    postgres-cron-backup:
        image: evoweb/postgres-cron-backup:18
        depends_on:
            - postgres
        volumes:
            - ${VOLUME_PATH}/backup:/backup
        environment:
            - POSTGRES_HOST=my_postgres
            - POSTGRES_USER=${POSTGRES_USER}
            - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
            - MAX_BACKUPS=15
            - INIT_RESTORE_LATEST=1
            - EXIT_BACKUP=1
            # Every day at 03:00
            - CRON_TIME=0 3 * * *
            # Make it small
            - GZIP_LEVEL=9
        restart: unless-stopped

volumes:
    data:
```

Docker database image could expose a directory you could add files as init sql script.

```yaml
services:
    postgres:
        image: postgres
        expose:
            - 5432
        volumes:
            - data:/var/lib/postgresql
            # If there is no scheme, restore using the init script (if exists)
            - ./init-script.sql:/docker-entrypoint-initdb.d/database.sql
        environment:
            - POSTGRES_DB=${DATABASE_NAME}
            - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
        restart: unless-stopped
```


## Testing

For local testing you need to install some helper packages
```bash
sudo apt-get install -y devscripts shellcheck
```
Build and check an image for a PostgreSQL major version:
```shell
docker buildx build --load --no-cache --compress --progress=plain --build-arg POSTGRES_VERSION=18 --tag evoweb/postgres-cron-backup:18 .
docker run --rm evoweb/postgres-cron-backup:18 psql --version
```

Run backup and restore against a PostgreSQL server of the same version:
```shell
export POSTGRES_VERSION=18 VOLUME_PATH=/tmp/postgres POSTGRES_DB=foo POSTGRES_USER=bar POSTGRES_PASSWORD=baz
docker compose up -d --wait postgres
docker compose run --rm --build backup /Scripts/backup.sh
docker compose run --rm backup /Scripts/restore.sh /backup/latest.foo.sql.gz
docker compose down -v
```


## Release

Notes that cannot be derived from the commit subjects, like breaking changes, go into `Build/ReleaseNotes/<release>.md` and have to be committed first. Then create and push the release:

```shell
make release RELEASE=x.y.z
git push origin main x.y.z
```

`make release` writes `CHANGELOG.md`, commits it as `[TASK] Release x.y.z` and tags that commit, so the tag contains its own changelog. Pushing the tag publishes the images, the Docker Hub description and a GitHub release with the changelog section of that release.
