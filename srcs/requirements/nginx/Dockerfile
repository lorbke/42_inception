FROM alpine:3.16

RUN apk add --update nginx \
    && mkdir -p /run/nginx \
    && apk add openssl

COPY conf/nginx.conf /etc/nginx/http.d/


COPY tools/generate_ssl.sh .
RUN sh generate_ssl.sh \
    && mv lorbke.42.fr.key /etc/ssl/private/ \
    && mv lorbke.42.fr.crt /etc/ssl/certs/

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]