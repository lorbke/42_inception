FROM alpine:3.16

RUN apk add --no-cache \
    php8 \
    php8-fpm \
    php8-mysqli \
    php8-json \
    php8-openssl \
    php8-curl \
    php8-zlib \
    php8-xml \
    php8-phar \
    php8-intl \
    php8-dom \
    php8-xmlreader \
    php8-ctype \
    php8-session \
    php8-mbstring \
    curl \
	bash

RUN curl -o wordpress.tar.gz -fSL "https://wordpress.org/latest.tar.gz" \
    && mkdir -p /var/www/html \
    && tar -xzf wordpress.tar.gz -C /var/www/html/ \
    && rm wordpress.tar.gz \
    && chown -R nobody:nobody /var/www/html/wordpress

EXPOSE 9000

CMD ["php-fpm8", "-F"]
