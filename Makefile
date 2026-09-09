all: create
	docker compose -f ./srcs/docker-compose.yml up -d --build

create:
	@mkdir -p $(HOME)/data/mariadb
	@mkdir -p $(HOME)/data/wordpress

down:
	docker compose -f ./srcs/docker-compose.yml down

clean: down
	docker compose -f ./srcs/docker-compose.yml rm -v

fclean:
	docker compose -f ./srcs/docker-compose.yml down -v --rmi all
	sudo rm -rf $(HOME)/data/mariadb
	sudo rm -rf $(HOME)/data/wordpress

re: fclean all

.PHONY: all create down clean fclean re
