FROM alpine:3.17

RUN apk add --no-cache mariadb mariadb-client

WORKDIR /var/lib/mysql

# Create initial database setup script
RUN mkdir -p /docker-entrypoint-initdb.d

EXPOSE 3306

CMD ["mysqld", "--bind-address=0.0.0.0"]
