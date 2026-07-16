FROM alpine:3.23

RUN apk add --no-cache busybox-extras

COPY site/ /var/www/static/

EXPOSE 3000

CMD ["httpd", "-f", "-p", "3000", "-h", "/var/www/static"]