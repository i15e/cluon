.PHONY: build run

all: build run

build:
	DOCKER_BUILDKIT=1 docker build --progress plain -t local/cluon:latest .

run:
	docker run -it --rm --name cluon -p 8080:8080 local/cluon:latest
