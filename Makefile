NAME = inception

all: data up

data:
	@mkdir -p /home/$(USER)/data/wordpress
	@mkdir -p /home/$(USER)/data/mariadb

clean: down
	@echo "Cleaning..."
	-@docker volume rm srcs_db_volume srcs_wp_volume

build:
	@echo "Building..."
	@docker compose -f srcs/docker-compose.yml build

up:
	@echo "Starting..."
	@docker compose -f srcs/docker-compose.yml up

down:
	@echo "Stopping..."
	@docker compose -f srcs/docker-compose.yml down

re: clean build all

.PHONY: all down up data clean build re