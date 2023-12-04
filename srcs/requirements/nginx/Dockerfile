FROM alpine:3.16

RUN apk add --update nginx \
    && mkdir -p /run/nginx

COPY conf/nginx.conf /etc/nginx/nginx.conf

COPY tools/lorbke.42.fr.crt /etc/ssl/certs/
COPY tools/lorbke.42.fr.key /etc/ssl/private/

EXPOSE 443

CMD ["nginx"]