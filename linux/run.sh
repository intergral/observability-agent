#!/bin/sh

# Run the autoconfiguration script in the background
/bin/bash /observability-agent-autoconf.sh --install false --config.file /etc/alloy/config.alloy --prompt false &

# Save the PID (Process IDentifier) of the first process
PID=$!

# Wait for the first process to finish
wait $PID

# Execute the grafana-agent-flow command
exec /bin/alloy run --server.http.listen-addr=0.0.0.0:12345 /etc/alloy/config.alloy "$@"