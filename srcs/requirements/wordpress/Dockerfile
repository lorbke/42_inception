FROM alpine:3.23

RUN apk add --no-cache \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-json \
    php83-openssl \
    php83-curl \
    php83-zlib \
    php83-xml \
    php83-phar \
    php83-intl \
    php83-dom \
    php83-xmlreader \
    php83-ctype \
    php83-session \
    php83-mbstring \
    curl

# fixes for errors that came up with newer alpine version
RUN ln -sf /usr/bin/php83 /usr/bin/php
RUN sed -i 's/^memory_limit = .*/memory_limit = 512M/' /etc/php83/php.ini

COPY tools/edit_www_conf.sh .

COPY tools/init_wordpress.sh .
RUN chmod +x init_wordpress.sh

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

EXPOSE 9000

ENTRYPOINT ["/init_wordpress.sh"]
CMD ["php-fpm83", "-F"]