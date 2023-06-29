ARG PLATFORM
FROM alpine:latest AS builder

ADD observability-agent-flow-autoconf.sh .
RUN chmod +x observability-agent-flow-autoconf.sh

ADD run.sh .
RUN chmod +x run.sh

FROM grafana/agent:latest
ENV AGENT_MODE=flow

COPY --from=builder observability-agent-flow-autoconf.sh .
COPY --from=builder run.sh .

RUN /observability-agent-flow-autoconf.sh --warm true

ENTRYPOINT ["/run.sh"]