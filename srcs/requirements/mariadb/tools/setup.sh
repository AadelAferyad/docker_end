#!/bin/bash
set -e
unset MYSQL_HOST

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

if [ ! -d /var/lib/mysql/mysql ]; then
	mariadb-install-db --user=mysql --datadir=/var/lib/mysql --auth-root-authentication-method=normal
	mariadbd --datadir=/var/lib/mysql --user=mysql &
	until mysqladmin ping > /dev/null 2>&1; do
		sleep 1
	done
	mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;"
	mysql -u root -e "CREATE USER IF NOT EXISTS \`${MYSQL_USER}\`@'%' IDENTIFIED BY '$(cat /run/secrets/db_password)';"
	mysql -u root -e "GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO \`${MYSQL_USER}\`@'%';"
	mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$(cat /run/secrets/db_root_password)';"
	MYSQL_PWD="$(cat /run/secrets/db_root_password)" mysqladmin -u root shutdown
fi
exec mariadbd --datadir=/var/lib/mysql --user=mysql
