AGENT_IMAGE ?= intergralgmbh/observability-agent:latest

amd64-image:
	echo "Building image for amd64 platform..."; \
	DOCKER_BUILDKIT=1 docker build --no-cache --progress=plain --platform=amd64 $(DOCKER_FLAGS) \
		--build-arg PLATFORM=amd64 \
		-t $(AGENT_IMAGE) \
		-f ./Dockerfile . ; \

arm64-image:
	echo "Building image for arm64 platform..."; \
	DOCKER_BUILDKIT=1 docker build --no-cache --progress=plain --platform=arm64 $(DOCKER_FLAGS) \
		--build-arg PLATFORM=arm64 \
		-t $(AGENT_IMAGE) \
		-f ./Dockerfile . ; \