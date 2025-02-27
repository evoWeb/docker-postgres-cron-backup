#!/bin/bash

# Get hostname: try read from file, else get from env
[ -z "${POSTGRES_HOST_FILE}" ] || { POSTGRES_HOST=$(head -1 "${POSTGRES_HOST_FILE}"); }
[ -z "${POSTGRES_HOST}" ] && { echo "=> POSTGRES_HOST cannot be empty" && exit 1; }
[ -z "${POSTGRES_PORT}" ] && { POSTGRES_PORT=5432; }

# Get username: try read from file, else get from env
[ -z "${POSTGRES_USER_FILE}" ] || { POSTGRES_USER=$(head -1 "${POSTGRES_USER_FILE}"); }
[ -z "${POSTGRES_USER}" ] && { echo "=> POSTGRES_USER cannot be empty" && exit 1; }

# Get password: try read from file, else get from env, else get from POSTGRES_PASSWORD env
[ -z "${POSTGRES_PASSWORD_FILE}" ] || { POSTGRES_PASSWORD=$(head -1 "${POSTGRES_PASSWORD_FILE}"); }
[ -z "${POSTGRES_PASSWORD}" ] && { echo "=> POSTGRES_PASSWORD cannot be empty" && exit 1; }

# Get database name(s): try read from file, else get from env
# Note: when from file, there can be one database name per line in that file
[ -z "${POSTGRES_DB_FILE}" ] || { POSTGRES_DB=$(cat "${POSTGRES_DB_FILE}"); }

# Get level from env, else use 6
[ -z "${GZIP_LEVEL}" ] && { GZIP_LEVEL=6; }

DATE=$(date +%Y%m%d%H%M)
echo "=> Backup started at $(date "+%Y-%m-%d %H:%M:%S")"
# shellcheck disable=SC2086
DATABASES=${POSTGRES_DB:-${POSTGRES_DB:-$(PGPASSWORD=${POSTGRES_PASSWORD} psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" ${PSQL_SSL_OPTS} -c "SELECT datname FROM pg_database" | tr -d "| " | grep -v Database)}}
for DB in ${DATABASES}
do
    if  [[ "${DB}" != "template0" ]] \
        && [[ "${DB}" != "template1" ]] \
        && [[ "${DB}" != "postgres" ]] \
        && [[ "${DB}" != "datname" ]] \
        && [[ "${DB}" != *rows* ]] \
        && [[ "${DB}" != -* ]] \
        && [[ "${DB}" != _* ]]
    then
        echo "==> Dumping database: ${DB}"
        FILENAME=/backup/$DATE.${DB}.sql
        LATEST=/backup/latest.${DB}.sql
        # shellcheck disable=SC2086
        if PGPASSWORD=${POSTGRES_PASSWORD} pg_dump ${PG_DUMP_OPTS} -C -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" ${PSQL_SSL_OPTS} "${DB}" > "${FILENAME}"
        then
            EXT=
            if [ -z "${USE_PLAIN_SQL}" ]
            then
                echo "==> Compressing ${DB} with LEVEL ${GZIP_LEVEL}"
                gzip "-${GZIP_LEVEL}" -n -f "${FILENAME}"
                EXT=.gz
                FILENAME=${FILENAME}${EXT}
                LATEST=${LATEST}${EXT}
            fi
            BASENAME=$(basename "${FILENAME}")
            echo "==> Creating symlink to latest backup: ${BASENAME}"
            rm "${LATEST}" 2> /dev/null
            cd /backup || exit && ln -s "${BASENAME}" "$(basename "${LATEST}")"
            if [ -n "${MAX_BACKUPS}" ]
            then
                # Execute the delete script, delete older backup or other custom delete script
                /Scripts/delete.sh "${DB}" ${EXT}
            fi
        else
            rm -rf "${FILENAME}"
        fi
    fi
done
echo "=> Backup process finished at $(date "+%Y-%m-%d %H:%M:%S")"
