#!/bin/bash

initialize_mariadb() {
	mysqld -uroot &
	while ! mysqladmin ping; do
		sleep 1
	done

	mysql -uroot -e "CREATE DATABASE ${WORDPRESS_DB}; CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}'; GRANT ALL PRIVILEGES ON ${WORDPRESS_DB}.* TO '${MYSQL_USER}'@'%';"
	mysqladmin -uroot shutdown
}

if [ ! -d "/var/lib/mysql/wordpress_db" ]; then
	initialize_mariadb
fi

# executes whatever was passed as an argument, in this case the argument is passed by CMD directive in Dockerfile
exec "$@"