#!/bin/sh

# Run the autoconfiguration script in the background
/observability-agent-autoconf.sh --install false --config.file /etc/agent/agent.yaml --prompt false &

# Save the PID (Process IDentifier) of the first process
PID=$!

# Wait for the first process to finish
wait $PID

# Execute the grafana-agent command
exec /bin/grafana-agent --config.file=/etc/agent/agent.yaml --metrics.wal-directory=/etc/agent/data "$@"