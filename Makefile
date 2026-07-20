NAME = inception
VOLUME_PATH = /Users/luca/Coding/42_inception/data/

all: create_vols up

create_vols:
	@mkdir -p ${VOLUME_PATH}/wordpress
	@mkdir -p ${VOLUME_PATH}/mariadb

clean: down
	@echo "Cleaning..."
	-@docker volume rm srcs_db_volume srcs_wp_volume

fclean: clean
	-@rm -rf data

build:
	@echo "Building..."
	@docker compose -f srcs/docker-compose.yml build

up: create_vols
	@echo "Starting..."
	@docker compose -f srcs/docker-compose.yml up -d --build

down:
	@echo "Stopping..."
	@docker compose -f srcs/docker-compose.yml down

re: fclean build all

.PHONY: all down up data fclean clean build re