unmatched:
	sudo rm -rf ./image/*
	DOCKER_BUILDKIT=1 docker-compose build nvme 
	docker-compose up nvme 


clean:
	sudo rm -rf ./image/*
	DOCKER_BUILDKIT=1 docker-compose build --no-cache
	docker-compose up
