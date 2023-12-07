#!/bin/sh

sleep 3

while ! nc -z mariadb 3306; do
  sleep 1
done

if [ ! -f "/var/www/html/wp-config.php" ]; then
  wp core download --path=/var/www/html/ --allow-root
  cd /var/www/html/
  wp config create --dbname=$DB_NAME --dbhost=$DB_HOST \
  --dbuser=$DB_USER --dbpass=$DB_PASSWORD --allow-root
  wp core install --skip-email --url=$DOMAIN_NAME --title="WordPress Site" \
  --admin_user="master" --admin_password="master" \
  --admin_email="master@example.com" --path=/var/www/html/ --allow-root
  wp user create "author" "author@example.com" --role=author --user_pass="author" \
  --path=/var/www/html/ --allow-root
fi

cd /
sh edit_www_conf.sh

exec "$@"