#!/usr/bin/env sh
dockerize -wait "tcp://${POSTGRES_HOST}:${POSTGRES_PORT}" -timeout "${TIMEOUT}" /Scripts/run.sh
