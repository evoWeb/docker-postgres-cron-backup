# Build dockerize
FROM golang:1.25.1-alpine3.22 AS binary
RUN apk -U add openssl git

ARG DOCKERIZE_VERSION=v0.9.6
ENV GO111MODULE=on

WORKDIR /go/src/github.com/jwilder
RUN git clone https://github.com/jwilder/dockerize.git \
    && cd dockerize \
    && git checkout ${DOCKERIZE_VERSION} \
    && go mod tidy \
    && CGO_ENABLED=0 GOOS=linux GO111MODULE=${GO111MODULE} go build -a -o /go/bin/dockerize .

# Export container
FROM alpine:3.22
LABEL maintainer="Sebastian Fischer <postgres-cron-backup@evoweb.de>"

ENV CRON_TIME="0 3 * * sun" \
    POSTGRES_HOST="postgres" \
    POSTGRES_PORT="5432" \
    TIMEOUT="10s" \
    PG_DUMP_OPTS="--rows-per-insert=1" \
    VERSION=17

COPY --from=binary /go/bin/dockerize /usr/local/bin
COPY ["/Scripts/run.sh", "/Scripts/backup.sh", "/Scripts/restore.sh", "/Scripts/delete.sh", "/Scripts/dockerize.sh", "/Scripts/"]

RUN --mount=type=cache,target=/var/cache/apk apk add --update \
    tzdata \
    bash \
    gzip \
    openssl \
    postgresql${VERSION}-client \
    fdupes \
    && mkdir /backup \
    && chmod 777 /backup \
    && chmod 755 /Scripts/*.sh \
    && touch /postgres_backup.log \
    && chmod 666 /postgres_backup.log

VOLUME ["/backup"]

HEALTHCHECK \
    --interval=60s \
    --retries=1800 \
    --start-period=20s \
    CMD stat /HEALTHY.status || exit 1

CMD ["/Scripts/dockerize.sh"]
