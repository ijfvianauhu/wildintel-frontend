FROM --platform=$BUILDPLATFORM caddy:2-builder-alpine AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN CGO_ENABLED=0 GOOS=${TARGETPLATFORM%/*} GOARCH=${TARGETPLATFORM#*/} xcaddy build --with github.com/caddyserver/replace-response

FROM --platform=$TARGETPLATFORM caddy:2-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

ARG APP_NAME=trapper-frontend-cs
COPY ./dist/apps/${APP_NAME}  /srv/
COPY ./caddy/Caddyfile /etc/caddy/Caddyfile
