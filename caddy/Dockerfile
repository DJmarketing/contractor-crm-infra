# Custom Caddy build with the Cloudflare DNS plugin, needed for
# DNS-01 wildcard certificates (*.contractor-crm.com).
FROM caddy:2-builder AS builder
RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
