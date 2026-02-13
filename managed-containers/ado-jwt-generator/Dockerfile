FROM alpine@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659

# Install dependencies in one layer, without caching the index
RUN apk add --no-cache \
    ca-certificates=20241121-r1 \
    curl=8.12.1-r1 \
    jq=1.7.1-r0 \
    openssl=3.3.3-r0


COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN addgroup -S jwt \
 && adduser  -S -G jwt jwt

USER jwt
ENTRYPOINT ["/entrypoint.sh"]
