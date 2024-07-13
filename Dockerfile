FROM golang:1.20.4-alpine3.18 AS binary

RUN apk -U add openssl git

ARG DOCKERIZE_VERSION=v0.7.0
WORKDIR /go/src/github.com/jwilder
RUN git clone https://github.com/jwilder/dockerize.git \
  && cd dockerize \
  && git checkout ${DOCKERIZE_VERSION}

ENV GO111MODULE=on
WORKDIR /go/src/github.com/jwilder/dockerize
RUN go mod tidy; \
    CGO_ENABLED=0 GOOS=linux GO111MODULE=${GO111MODULE} go build -a -o /go/bin/dockerize .

FROM alpine:3.20
LABEL maintainer="Sebastian Fischer <postgres-cron-backup@evoweb.de>"

ENV CRON_TIME="0 3 * * sun" \
    POSTGRES_HOST="postgres" \
    POSTGRES_PORT="5432" \
    TIMEOUT="10s" \
    PG_DUMP_OPTS=""
VOLUME ["/backup"]

RUN apk add --update \
        tzdata \
        bash \
        postgresql-client \
        gzip \
        openssl && \
    rm -rf /var/cache/apk/*

COPY --from=binary /go/bin/dockerize /usr/local/bin
COPY /Scripts /Scripts

RUN mkdir /backup && \
    chmod 777 /backup && \
    chmod 755 /Scripts/*.sh && \
    touch /mysql_backup.log && \
    chmod 666 /mysql_backup.log

HEALTHCHECK \
    --interval=60s \
    --retries=1800 \
    --start-period=20s \
    CMD stat /HEALTHY.status || exit 1

CMD dockerize -wait tcp://${POSTGRES_HOST}:${POSTGRES_PORT} -timeout ${TIMEOUT} /Scripts/run.sh
