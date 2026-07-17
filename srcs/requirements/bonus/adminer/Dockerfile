FROM alpine:3.23

RUN apk add --no-cache \
    php83 \
    php83-mysqli \
    php83-session \
    curl

RUN ln -sf /usr/bin/php83 /usr/bin/php

RUN mkdir -p /var/www/adminer \
    && curl -L -o /var/www/adminer/index.php \
       https://github.com/vrana/adminer/releases/download/v5.4.4/adminer-5.4.4.php

EXPOSE 8080

CMD ["php", "-S", "0.0.0.0:8080", "-t", "/var/www/adminer"]