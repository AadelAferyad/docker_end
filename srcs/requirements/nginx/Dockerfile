FROM debian:bookworm

RUN apt update
RUN apt install -y nginx openssl && rm -rf /var/lib/apt/lists/*

COPY config/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 443

COPY tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

ENTRYPOINT ["/usr/local/bin/setup.sh"]
