AGENT_IMAGE ?= intergralgmbh/observability-agent:latest

amd64-image:
	echo "Building image for amd64 platform..."; \
	DOCKER_BUILDKIT=1 docker build --no-cache --progress=plain $(DOCKER_FLAGS) \
		--build-arg PLATFORM=amd64 \
		-t $(AGENT_IMAGE) \
		-f ./Dockerfile . ; \

ppc64le-image:
	echo "Building image for ppc64le platform..."; \
	DOCKER_BUILDKIT=1 docker build --no-cache --progress=plain $(DOCKER_FLAGS) \
		--build-arg PLATFORM=ppc64le \
		-t $(AGENT_IMAGE) \
		-f ./Dockerfile . ; \

arm64-image:
	echo "Building image for arm64 platform..."; \
	DOCKER_BUILDKIT=1 docker build --no-cache --progress=plain $(DOCKER_FLAGS) \
		--build-arg PLATFORM=arm64 \
		-t $(AGENT_IMAGE) \
		-f ./Dockerfile . ; \