ARG PLATFORM
FROM alpine:latest AS builder

ADD observability-agent-autoconf.sh .
RUN chmod +x observability-agent-autoconf.sh

ADD run.sh .
RUN chmod +x run.sh

FROM grafana/alloy:latest

COPY --from=builder observability-agent-autoconf.sh .
COPY --from=builder run.sh .

RUN /observability-agent-autoconf.sh --warm true

ENTRYPOINT ["/run.sh"]