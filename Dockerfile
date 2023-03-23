FROM alpine:latest

LABEL maintainer="Florian Gaudin florian.gaudin@apprentis-auteuil.org"

RUN apk add --no-cache --update bash bind-tools vim postfix tzdata ca-certificates \
    && rm -rf /var/cache/apk/*

EXPOSE 25

COPY entrypoint.sh /usr/local/bin/
ENTRYPOINT ["entrypoint.sh"]