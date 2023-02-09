FROM alpine:latest

RUN apk add --no-cache --update bash vim postfix \
    && rm -rf /var/cache/apk/*

EXPOSE 25

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]