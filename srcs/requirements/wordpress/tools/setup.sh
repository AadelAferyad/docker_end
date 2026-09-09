#!/bin/bash

set -e

DB_PASSWORD="$(cat /run/secrets/db_password)"

until mysql \
    -h "$MYSQL_HOST" \
    -u "$MYSQL_USER" \
    -p"$DB_PASSWORD" \
    -e "SELECT 1" "$MYSQL_DATABASE" >/dev/null 2>&1
do
    sleep 2
done

if echo "${WP_ADMIN_USER}" | grep -iq "admin"; then
	echo "ERROR: WP_ADMIN_USER contains 'admin' subs on it."
	exit 1
fi

if [ ! -f "wp-config.php" ]; then
	wp core download --allow-root
	wp config create \
		--allow-root \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="$(cat /run/secrets/db_password)" \
		--dbhost="mariadb:3306"
	wp core install \
		--allow-root \
		--url="https://${DOMAIN_NAME}" \
		--title="inception" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="$(cat /run/secrets/wp_admin_password)" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email
	wp user create \
		--allow-root \
		"${WP_USER}" \
		"${WP_EMAIL}" \
		--user_pass="$(cat /run/secrets/wp_user_password)" \
		--role=author
fi

chown -R www-data:www-data /var/www/html/wordpress

exec /usr/sbin/php-fpm8.2 -F
