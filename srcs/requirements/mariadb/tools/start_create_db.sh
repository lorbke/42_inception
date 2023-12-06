#!/bin/sh

initialize_mariadb() {
	mysqld -uroot &
	while ! mysqladmin ping; do
		sleep 1
	done

	mysql -uroot -e " \
	DELETE FROM mysql.user WHERE User='';
	DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1'); \
	CREATE DATABASE ${DB_NAME}; \
	CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}'; \
	GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';"
	mysqladmin -uroot shutdown
}

if [ ! -d "/var/lib/mysql/DB_NAME" ]; then
	initialize_mariadb
fi

# executes whatever was passed as an argument, in this case the argument is passed by CMD directive in Dockerfile
exec "$@"