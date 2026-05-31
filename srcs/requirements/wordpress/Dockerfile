FROM alpine:3.18

RUN apk add --no-cache php php-fpm php-mysqli php-json php-curl \
    php-dom php-exif php-fileinfo php-mbstring php-openssl \
    php-xml wget

WORKDIR /var/www/html

# Download WordPress
RUN wget https://wordpress.org/latest.tar.gz && \
    tar -xzf latest.tar.gz && \
    mv wordpress/* . && \
    rm -rf wordpress latest.tar.gz

# Configure PHP-FPM
RUN mkdir -p /run/php && \
    sed -i 's/listen = 127.0.0.1:9000/listen = 0.0.0.0:9000/' /etc/php*/php-fpm.d/www.conf

EXPOSE 9000

CMD ["php-fpm", "-F"]
