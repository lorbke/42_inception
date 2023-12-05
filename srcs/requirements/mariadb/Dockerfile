FROM alpine:3.16

RUN apk update \
	&& apk add mariadb mariadb-client bash \
	&& mkdir -p /var/lib/mysql \
	&& mkdir -p /run/mysqld \
	&& chown -R mysql:mysql /run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql \
	&& mysql_install_db --user=mysql --datadir=/var/lib/mysql

COPY tools/edit_server_config.sh .
RUN sh edit_server_config.sh

COPY tools/create_wordpress_db.sql .
RUN mysqld --user=mysql --bootstrap < create_wordpress_db.sql

EXPOSE 3306

CMD ["mysqld", "--user=mysql"]