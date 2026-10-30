ARG POSTGRES_VERSION=18

# Build dockerize natively and cross-compile it for the target platform
FROM --platform=$BUILDPLATFORM golang:1.27.3-alpine3.24 AS binary
RUN apk -U add git

ARG DOCKERIZE_VERSION=v0.16.0
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /go/src/github.com/jwilder
RUN git clone --depth 1 --branch ${DOCKERIZE_VERSION} https://github.com/jwilder/dockerize.git \
    && cd dockerize \
    && CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT#v} \
       go build -a -ldflags "-X main.buildVersion=${DOCKERIZE_VERSION}" -o /go/bin/dockerize .

# Export container
FROM alpine:3.24
ARG POSTGRES_VERSION
LABEL maintainer="Sebastian Fischer <postgres-cron-backup@evoweb.de>"

ENV CRON_TIME="0 3 * * sun" \
    POSTGRES_HOST="postgres" \
    POSTGRES_PORT="5432" \
    TIMEOUT="10s" \
    PG_DUMP_OPTS="--rows-per-insert=1" \
    POSTGRES_VERSION=${POSTGRES_VERSION}

COPY --from=binary /go/bin/dockerize /usr/local/bin
COPY ["/Scripts/run.sh", "/Scripts/backup.sh", "/Scripts/restore.sh", "/Scripts/delete.sh", "/Scripts/dockerize.sh", "/Scripts/"]

RUN --mount=type=cache,target=/var/cache/apk apk add --update \
    tzdata \
    bash \
    gzip \
    openssl \
    postgresql${POSTGRES_VERSION}-client \
    fdupes \
    && mkdir /backup \
    && chmod 777 /backup \
    && chmod 755 /Scripts/*.sh \
    && touch /postgres_backup.log \
    && chmod 666 /postgres_backup.log

VOLUME ["/backup"]

# Healthy once the init phase is done, unhealthy as soon as the last backup failed.
# The long start period covers a slow INIT_BACKUP or INIT_RESTORE_LATEST.
HEALTHCHECK \
    --interval=60s \
    --retries=3 \
    --start-period=1h \
    CMD [ -f /HEALTHY.status ] && [ ! -f /FAILED.status ] || exit 1

CMD ["/Scripts/dockerize.sh"]
