AGENT_IMAGE ?= intergral/grafana/agent:main

amd64-image:
	echo "Building image for amd64 platform..."; \
	DOCKER_BUILDKIT=1 docker build --no-cache --progress=plain $(DOCKER_FLAGS) \
		--build-arg PLATFORM=amd64 \
		-t $(AGENT_IMAGE)-amd64 \
		-f ./Dockerfile . ; \

ppc64le-image:
	echo "Building image for ppc64le platform..."; \
	DOCKER_BUILDKIT=1 docker build --no-cache --progress=plain $(DOCKER_FLAGS) \
		--build-arg PLATFORM=ppc64le \
		-t $(AGENT_IMAGE)-ppc64le \
		-f ./Dockerfile . ; \

arm64-image:
	echo "Building image for arm64 platform..."; \
	DOCKER_BUILDKIT=1 docker build --no-cache --progress=plain $(DOCKER_FLAGS) \
		--build-arg PLATFORM=arm64 \
		-t $(AGENT_IMAGE)-arm64 \
		-f ./Dockerfile . ; \