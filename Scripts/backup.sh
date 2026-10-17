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

set -o pipefail

# Stream the dump through gzip, so no uncompressed copy hits the disk and gzip
# never has to copy file modes, which fails on root_squashed NFS shares
function dump_database {
    # shellcheck disable=SC2086
    PGPASSWORD=${POSTGRES_PASSWORD} pg_dump ${PG_DUMP_OPTS} -C -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" ${PSQL_SSL_OPTS} "${1}" \
        | if [ -z "${USE_PLAIN_SQL}" ]; then gzip "-${GZIP_LEVEL}" -n; else cat; fi
}

DATE=$(date +%Y%m%d%H%M)
FAILED=0
echo "=> Backup started at $(date "+%Y-%m-%d %H:%M:%S")"
# shellcheck disable=SC2086
DATABASES=${POSTGRES_DB:-$(PGPASSWORD=${POSTGRES_PASSWORD} psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" ${PSQL_SSL_OPTS} -c "SELECT datname FROM pg_database" | tr -d "| " | grep -v Database)}
[ -z "${DATABASES}" ] && { echo "==> ERROR: No database found to back up"; FAILED=1; }
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
        EXT=
        [ -z "${USE_PLAIN_SQL}" ] && EXT=.gz
        FILENAME=/backup/$DATE.${DB}.sql${EXT}
        LATEST=/backup/latest.${DB}.sql${EXT}
        echo "==> Dumping database: ${DB}"
        # Write to a temporary name first, delete.sh must never count an incomplete dump
        if dump_database "${DB}" > "${FILENAME}.tmp" && mv "${FILENAME}.tmp" "${FILENAME}"
        then
            BASENAME=$(basename "${FILENAME}")
            echo "==> Creating symlink to latest backup: ${BASENAME}"
            rm "${LATEST}" 2> /dev/null
            cd /backup || exit 1 && ln -s "${BASENAME}" "$(basename "${LATEST}")"
            if [ -n "${MAX_BACKUPS}" ]
            then
                # Execute the delete script, delete older backup or other custom delete script
                /Scripts/delete.sh "${DB}" ${EXT}
            fi
        else
            echo "==> ERROR: Dumping database ${DB} failed, keeping existing backups"
            rm -f "${FILENAME}.tmp"
            FAILED=$((FAILED + 1))
        fi
    fi
done

if [ "${FAILED}" -gt 0 ]
then
    touch /FAILED.status
    echo "=> Backup process failed at $(date "+%Y-%m-%d %H:%M:%S")"
    exit 1
fi
rm -f /FAILED.status
echo "=> Backup process finished at $(date "+%Y-%m-%d %H:%M:%S")"
