#!/bin/bash

# Get hostname: try read from file, else get from env
[ -z "${POSTGRES_HOST_FILE}" ] || { POSTGRES_HOST=$(head -1 "${POSTGRES_HOST_FILE}"); }
[ -z "${POSTGRES_HOST}" ] && { echo "=> POSTGRES_HOST cannot be empty" && exit 1; }

# Get username: try read from file, else get from env
[ -z "${POSTGRES_USER_FILE}" ] || { POSTGRES_USER=$(head -1 "${POSTGRES_USER_FILE}"); }
[ -z "${POSTGRES_USER}" ] && { echo "=> POSTGRES_USER cannot be empty" && exit 1; }

# Get password: try read from file, else get from env, else get from POSTGRES_PASSWORD env
[ -z "${POSTGRES_PASSWORD_FILE}" ] || { POSTGRES_PASSWORD=$(head -1 "${POSTGRES_PASSWORD_FILE}"); }
[ -z "${POSTGRES_PASSWORD}" ] && { echo "=> POSTGRES_PASSWORD cannot be empty" && exit 1; }

if [ "$#" -ne 1 ]
then
    echo "You must pass the path of the backup file to restore"
    exit 1
fi
BACKUP_FILE=${1}

set -o pipefail

if [ -z "${USE_PLAIN_SQL}" ]
then
    UNCOMPRESSED_FILE="${BACKUP_FILE/.sql.gz/.sql}"
    gunzip -c "${BACKUP_FILE}" > "${UNCOMPRESSED_FILE}"
    BACKUP_FILE="${UNCOMPRESSED_FILE}"
fi

DB_NAME=${POSTGRES_DB}
if [ -z "${DB_NAME}" ]
then
    echo "=> Searching database name in $1"
    DB_NAME=$(grep -oE '(CREATE DATABASE (.+))' ${BACKUP_FILE} | cut -d ' ' -f 3)
fi
[ -z "${DB_NAME}" ] && { echo "=> Database name not found" && exit 1; }

echo "=> Restore database ${DB_NAME} from $1"

if PGPASSWORD=${POSTGRES_PASSWORD} psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" ${PSQL_SSL_OPTS} "${DB_NAME}" < ${BACKUP_FILE}
then
    echo "=> Restore succeeded"
else
    echo "=> Restore failed"
fi
