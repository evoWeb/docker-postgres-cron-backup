# postgres-cron-backup

Periodic `pg_dump` backups of your PostgreSQL databases, scheduled by cron inside the container. Backups are gzipped and written to `/backup` — mount a host directory or a volume there.

Based on the work of [Javier Delgado](https://github.com/fradelg/docker-mysql-cron-backup). Source and issues: [github.com/evoWeb/docker-postgres-cron-backup](https://github.com/evoWeb/docker-postgres-cron-backup)

## Tags

Pick the tag matching the major version of your PostgreSQL server, so `pg_dump` and `psql` are compatible with it.

| Tag | PostgreSQL client |
|---|---|
| `18`, `18.x`, `18.x-<release>` | 18 |
| `17`, `17.x`, `17.x-<release>` | 17 |
| `16`, `16.x`, `16.x-<release>` | 16 |

Platforms: `linux/amd64`, `linux/arm64`, `linux/arm/v7`

## Quick start

```bash
docker container run -d \
    --env POSTGRES_HOST=my_postgres \
    --env POSTGRES_USER=postgres \
    --env POSTGRES_PASSWORD=my_password \
    --network my_network \
    --volume /path/to/backups:/backup \
    evoweb/postgres-cron-backup:18
```

## docker compose

```yaml
services:
    postgres:
        image: postgres:18
        volumes:
            - data:/var/lib/postgresql
        environment:
            POSTGRES_DB: ${POSTGRES_DB}
            POSTGRES_USER: ${POSTGRES_USER}
            POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
        restart: unless-stopped

    backup:
        image: evoweb/postgres-cron-backup:18
        depends_on:
            - postgres
        volumes:
            - ./backup:/backup
        environment:
            POSTGRES_HOST: postgres
            POSTGRES_DB: ${POSTGRES_DB}
            POSTGRES_USER: ${POSTGRES_USER}
            POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
            MAX_BACKUPS: 15
            INIT_BACKUP: 1
            CRON_TIME: 0 3 * * *
            GZIP_LEVEL: 9
        restart: unless-stopped

volumes:
    data:
```

Credentials can also be passed as [docker secrets](https://docs.docker.com/engine/swarm/secrets/) via the `*_FILE` variables, e.g. `POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password`.

## Environment variables

| Variable | Description | Default |
|---|---|---|
| `POSTGRES_HOST` / `POSTGRES_HOST_FILE` | Host of the PostgreSQL server | `postgres` |
| `POSTGRES_PORT` | Port of the PostgreSQL server | `5432` |
| `POSTGRES_USER` / `POSTGRES_USER_FILE` | Database user | — |
| `POSTGRES_PASSWORD` / `POSTGRES_PASSWORD_FILE` | Database password | — |
| `POSTGRES_DB` / `POSTGRES_DB_FILE` | Database(s) to back up; the file may list one name per line | all databases |
| `PG_DUMP_OPTS` | Additional [pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html) arguments | `--rows-per-insert=1` |
| `PSQL_SSL_OPTS` | Arguments to connect via [SSL](https://www.postgresql.org/docs/current/ssl-tcp.html) | — |
| `CRON_TIME` | Cron schedule of the backup | `0 3 * * sun` |
| `TZ` | Container timezone, e.g. `Europe/Berlin` | UTC |
| `MAX_BACKUPS` | Number of backups to keep per database | unlimited |
| `INIT_BACKUP` | Create a backup on container start (`1`) | — |
| `INIT_RESTORE_LATEST` | Restore the latest backup on container start | — |
| `EXIT_BACKUP` | Create a backup on container stop | — |
| `TIMEOUT` | Time to wait for the database on startup | `10s` |
| `GZIP_LEVEL` | gzip compression level, 1 (fast) to 9 (small) | `6` |
| `USE_PLAIN_SQL` | Write and restore plain SQL instead of gzip | — |

Backups are named `<YYYYMMDDHHMM>.<database>.sql.gz`, and `latest.<database>.sql.gz` links to the most recent one.

## Restore

```bash
# List backups
docker container exec <container> ls /backup

# Restore a backup; the database name is read from the dump if POSTGRES_DB is not set
docker container exec <container> /Scripts/restore.sh /backup/latest.<database>.sql.gz
```

## Healthcheck

The container is **healthy** once the init phase (`INIT_BACKUP` / `INIT_RESTORE_LATEST`) is done and turns **unhealthy** within three minutes when a backup fails. A backup fails when no database is found or `pg_dump`/`gzip` exits with an error; the incomplete dump is removed and existing backups are kept, so `MAX_BACKUPS` never rotates out a good backup in favor of a broken one.
