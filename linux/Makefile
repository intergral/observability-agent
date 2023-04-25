AGENT_IMAGE ?= intergral/grafana/agent:main

PLATFORMS := arm64 ppc64le

amd64-image:
	echo "Building image for amd64 platform..."; \
	DOCKER_BUILDKIT=1 docker build --no-cache --progress=plain $(DOCKER_FLAGS) \
		--build-arg PLATFORM=amd64 \
		-t $(AGENT_IMAGE)-amd64 \
		-f ./Dockerfile . ; \

other-images:
	@for platform in $(PLATFORMS); do \
		echo "Building image for $$platform platform..."; \
		DOCKER_BUILDKIT=1 docker build --no-cache --progress=plain $(DOCKER_FLAGS) \
			--build-arg PLATFORM=$$platform \
			-t $(AGENT_IMAGE)-$$platform \
			-f ./Dockerfile . ; \
	done