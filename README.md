# postgres-cron-backup

## Base on the work of [Javier Delgado](https://github.com/fradelg/docker-mysql-cron-backup)

Run pg_dump to back up your databases periodically using the cron task manager in the container. Your backups are saved in `/backup`. You can mount any directory of your host or a docker volumes in /backup. Otherwise, a docker volume is created in the default location.


## Usage:

```bash
docker container run -d \
       --env POSTGRES_USER=postgres \
       --env POSTGRES_PASSWORD=my_password \
       --link postgres
       --volume /path/to/my/backup/folder:/backup
       evoweb/postgres-cron-backup
```


### Healthcheck

Healthcheck is provided as a basic init control.
Container is **Healthy** after the database init phase, that is after `INIT_BACKUP` or `INIT_RESTORE_LATEST` happens without check if there is an error, **Starting** otherwise. Not other checks are actually provided.


## Variables

- `POSTGRES_HOST`: The host/ip of your postgres database.
- `POSTGRES_HOST_FILE`: The file in container where to find the host of your postgres database (cf. docker secrets). You should use either POSTGRES_HOST_FILE or POSTGRES_HOST (see examples below).
- `POSTGRES_PORT`: The port number of your postgres database.
- `POSTGRES_USER`: The username of your postgres database.
- `POSTGRES_USER_FILE`: The file in container where to find the user of your postgres database (cf. docker secrets). You should use either POSTGRES_USER_FILE or POSTGRES_USER (see examples below).
- `POSTGRES_PASSWORD`: The password of your postgres database.
- `POSTGRES_PASSWORD_FILE`: The file in container where to find the password of your postgres database (cf. docker secrets). You should use either POSTGRES_PASSWORD_FILE or POSTGRES_PASSWORD (see examples below).
- `POSTGRES_DB`: The database name to dump. Default: `--all-databases`.
- `POSTGRES_DB_FILE`: The file in container where to find the database name(s) in your postgres database (cf. docker secrets). In that file, there can be several database names: one per line. You should use either POSTGRES_DB or POSTGRES_DB_FILE (see examples below).
- `PG_DUMP_OPTS`: Command line arguments to pass to pg_dump (see [pg_dump documentation](https://www.postgresql.org/docs/current/app-pgdump.html)).
- `PSQL_SSL_OPTS`: Command line arguments to use [SSL](https://www.postgresql.org/docs/16/ssl-tcp.html).
- `CRON_TIME`: The interval of cron job to run pg_dump. `0 3 * * sun` by default, which is every Sunday at 03:00. It uses UTC timezone.
- `MAX_BACKUPS`: The number of backups to keep. When reaching the limit, the old backup will be discarded. No limit by default.
- `INIT_BACKUP`: If set, create a backup when the container starts.
- `INIT_RESTORE_LATEST`: If set, restores latest backup.
- `EXIT_BACKUP`: If set, create a backup when the container stops.
- `TIMEOUT`: Wait a given number of seconds for the database to be ready and make the first backup, `10s` by default. After that time, the initial attempt for backup gives up and only the Cron job will try to make a backup.
- `GZIP_LEVEL`: Specify the level of gzip compression from 1 (quickest, least compressed) to 9 (slowest, most compressed), default is 6.
- `USE_PLAIN_SQL`: If set, back up and restore plain SQL files without gzip.
- `TZ`: Specify TIMEZONE in Container. E.g. "Europe/Berlin". Default is UTC.

If you want to make this image the perfect companion of your Postgres container,
use [docker-compose](https://docs.docker.com/compose/). You can add more services
that will be able to connect to the Postgres image using the name `my_postgres`,
note that you only expose the port `5432` internally to the servers and not to the host:


### docker compose with POSTGRES_PASS env var:

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
  db:
    image: postgres
    container_name: my_postgres
    expose:
      - 5432
    volumes:
      - data:/var/lib/postgresql/data
      # If there is no scheme, restore the last created backup (if exists)
      - ${VOLUME_PATH}/backup/latest.${DATABASE_NAME}.sql.gz:/docker-entrypoint-initdb.d/database.sql.gz
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
    restart: unless-stopped
    networks:
      - backend

  postgres-cron-backup:
    image: evoweb/postgres-cron-backup
    depends_on:
      - db
    volumes:
      - backup:/backup
    environment:
      POSTGRES_HOST: db
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
        image: postgres:16
        container_name: my_postgres
        expose:
            - 5432
        volumes:
            - data:/var/lib/postgresql/data
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
        image: evoweb/postgres-cron-backup
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
        image: evoweb/postgres-cron-backup
        command: "/restore.sh /backup/201708060500.${DATABASE_NAME}.sql.gz"
        depends_on:
            - postgres
        volumes:
            - ${VOLUME_PATH}/backup:/backup
        environment:
            - POSTGRES_HOST=my_postgres
            - POSTGRES_USER=postgres
            - POSTGRES_DB=${DATABASE_NAME}
            - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
```


### Restore using a docker command

```bash
docker container exec <your_postgres_backup_container_name> /restore.sh /backup/<your_sql_backup_gz_file>
```

If no database name is specified, `restore.sh` will try to find the database name from the backup file.


### Automatic backup and restore on container starts and stops

Set `INIT_RESTORE_LATEST` to automatic restore the last backup on startup.
Set `EXIT_BACKUP` to automatically create a last backup on shutdown.

```yaml
services:
    postgres-cron-backup:
        image: evoweb/postgres-cron-backup
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
            - data:/var/lib/postgresql/data
            # If there is no scheme, restore using the init script (if exists)
            - ./init-script.sql:/docker-entrypoint-initdb.d/database.sql.gz
        environment:
            - POSTGRES_DB=${DATABASE_NAME}
            - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
        restart: unless-stopped
```

```yaml
services:
    postgres:
        image: postgres
        expose:
            - 5432
        volumes:
            - data:/var/lib/postgresql/data
            # If there is no scheme, restore using the init script (if exists)
            - ./init-script.sql:/docker-entrypoint-initdb.d/database.sql.gz
        environment:
            - POSTGRES_DATABASE=${DATABASE_NAME}
            - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
        restart: unless-stopped
```


## Testing

For local testing you need to install some helper packages
```bash
sudo apt-get install -y devscripts shellcheck
```
