NAME = inception

all:
	@echo "Compiling inception..."
	@docker compose -f srcs/docker-compose.yml up

clean:
	@echo "Cleaning..."
	@docker compose -f srcs/docker-compose.yml down

build:
	@echo "Building..."
	@docker compose -f srcs/docker-compose.yml build

re: clean build all

.PHONY: all clean build re