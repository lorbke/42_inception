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

COPY tools/start_create_db.sh .
RUN chmod +x start_create_db.sh

EXPOSE 3306

ENTRYPOINT ["/start_create_db.sh"]
CMD ["mysqld", "-uroot"]