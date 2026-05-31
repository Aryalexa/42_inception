.PHONY: build up down clean logs restart

build:
	docker-compose -f srcs/docker-compose.yml build

up:
	docker-compose -f srcs/docker-compose.yml up -d

down:
	docker-compose -f srcs/docker-compose.yml down

clean: down
	docker-compose -f srcs/docker-compose.yml down -v
	docker system prune -f

restart: down up

logs:
	docker-compose -f srcs/docker-compose.yml logs -f

ps:
	docker-compose -f srcs/docker-compose.yml ps
