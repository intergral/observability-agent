AGENT_IMAGE ?= intergral/grafana/agent:main
PLATFORMS := amd64 arm64 ppc64le

agent-images:
	@for platform in $(PLATFORMS); do \
		echo "Building image for $$platform platform..."; \
		DOCKER_BUILDKIT=1 docker build --no-cache --progress=plain $(DOCKER_FLAGS) \
			--build-arg PLATFORM=$$platform \
			-t $(AGENT_IMAGE)-$$platform \
			-f ./Dockerfile . ; \
	done