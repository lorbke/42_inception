#!/bin/sh

sleep 2

while ! nc -z mariadb 3306; do
  sleep 1
done

if ! wp core is-installed --allow-root --path=/var/www/html/wordpress; then
  cd /var/www/html/wordpress
  wp config create --dbname=$DB_NAME --dbhost=$DB_HOST \
  --dbuser=$DB_USER --dbpass=$DB_PASSWORD --allow-root
  wp core install --url="localhost" --title="WordPress Site" \
  --admin_user="master" --admin_password="master" \
  --admin_email="master@example.com" --path=/var/www/html/wordpress --allow-root
  wp user create "author" "author@example.com" --role=author --user_pass=$DB_PASSWORD \
  --path=/var/www/html/wordpress --allow-root
fi

cd /
sh edit_www_conf.sh

exec "$@"