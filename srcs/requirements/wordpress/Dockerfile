FROM debian:bookworm

RUN apt update
RUN apt-get install -y \
    php8.2-fpm \
    php8.2-mysql \
    mariadb-client \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

RUN mkdir -p /run/php
RUN mkdir -p /var/www/html/wordpress

RUN chown -R www-data:www-data /var/www/html/wordpress

WORKDIR /var/www/html/wordpress

COPY ./config/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY ./tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/setup.sh"]

