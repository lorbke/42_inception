#!/bin/sh

sleep 10

while ! nc -z mariadb 3306; do
  sleep 1
done

# Install WordPress if not already installed
if ! wp core is-installed --allow-root --path=/var/www/html/wordpress; then
  wp core install --url="localhost" --title="WordPress Site" \
  --admin_user="master" --admin_password="master" \
  --admin_email="master@example.com" --path=/var/www/html/wordpress --allow-root
fi

exec "$@"