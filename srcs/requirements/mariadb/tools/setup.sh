#!/bin/bash

set -e

mkdir -p /run/mysqld
chown mysql:mysql  /run/mysqld

if [ ! -d /var/lib/mysql/mysql ]; then
	mariadb-install_db --user=mysql --datadir=/var/lib/mysql
	mariadbd --datadir=/var/lib/mysql --user=mysql &
	until mysqladmin ping > /dev/null 2>&1; do
		sleep 1
	done
	mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;"
	mysql -u root -e "CREATE USER IF NOT EXISTS \`${MYSQL_USER}\`@'%' IDENTIFIED BY '$(cat /run/secrets/db_password)';"
	mysql -u root -e "GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO \`${MYSQL_USER}\`@'%';"
	mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$(cat /run/secrets/db_root_password)';"
	mysqladmin -u root -p"$(cat /run/secrets/db_root_password)" shutdown
fi

exec mariadbd --datadir=/var/lib/mysql --user=mysql

