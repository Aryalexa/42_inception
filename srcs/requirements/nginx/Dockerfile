FROM alpine:3.18

RUN apk add --no-cache nginx openssl

WORKDIR /etc/nginx

# Generate self-signed certificate for local testing
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/server.key \
    -out /etc/nginx/server.crt \
    -subj "/CN=mayrcast.42.fr"

COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
