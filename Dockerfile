FROM alpine:latest

LABEL maintainer="Florian Gaudin <florian.gaudin@apprentis-auteuil.org>"

#installation des paquets 
RUN apk add --no-cache --update bash vim postfix tzdata ca-certificates && \
    update-ca-certificates && \
    rm -rf /var/cache/apk/*

#mise à niveau de l'utilisateur postfix
RUN addgroup -g 1000 dockergid && \
    addgroup postfix dockergid

#port exposé
EXPOSE 25

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]