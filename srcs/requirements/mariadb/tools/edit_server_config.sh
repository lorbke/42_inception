#!/bin/sh

{ echo '[mysqld]'; \
	echo 'skip-host-cache'; \
	echo 'skip-name-resolve'; \
	echo 'bind-address=0.0.0.0'; \
} | tee  /etc/my.cnf.d/docker.cnf; \
sed -i "s|skip-networking|skip-networking=0|g" /etc/my.cnf.d/mariadb-server.cnf