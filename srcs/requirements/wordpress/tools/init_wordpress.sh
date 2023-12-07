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
  --admin_user=$WP_ADMIN --admin_password=$WP_ADMIN_PASSWORD \
  --admin_email=$WP_ADMIN_EMAIL --path=/var/www/html/ --allow-root
  wp user create $WP_USER $WP_USER_EMAIL --role=author --user_pass=$WP_USER_PASSWORD \
  --path=/var/www/html/ --allow-root
fi

cd /
sh edit_www_conf.sh

exec "$@"