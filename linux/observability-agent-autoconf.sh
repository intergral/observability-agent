#!/bin/bash
# Flags
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config.file)
      CONFIG="$2"
      shift 2
      ;;
    --install)
      case "$2" in
        false)
          INSTALL=false
          ;;
        *)
          echo "Invalid value for --install flag: $2" >&2
          exit 1
          ;;
      esac
      shift 2
      ;;
    --prompt)
      case "$2" in
        false)
          PROMPT=false
          ;;
        *)
          echo "Invalid value for --prompt flag: $2" >&2
          exit 1
          ;;
      esac
      shift 2
      ;;
    --warm)
      case "$2" in
        true)
          WARM=true
          ;;
        *)
          echo "Invalid value for --warm flag: $2" >&2
          exit 1
          ;;
      esac
      shift 2
      ;;
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

# OS/Distro Detection
# Try lsb_release, fallback with /etc/issue then uname command
KNOWN_DISTRIBUTION="(Debian|Ubuntu|RedHat|CentOS|openSUSE|Amazon|Arista|SUSE|Rocky|AlmaLinux|Darwin)"
DISTRIBUTION=$(lsb_release -d 2>/dev/null | grep -Eo $KNOWN_DISTRIBUTION  || grep -Eo $KNOWN_DISTRIBUTION /etc/issue 2>/dev/null || grep -Eo $KNOWN_DISTRIBUTION /etc/Eos-release 2>/dev/null || grep -m1 -Eo $KNOWN_DISTRIBUTION /etc/os-release 2>/dev/null || uname -s)

if [ -f /etc/debian_version ] || [ "$DISTRIBUTION" = "Debian" ] || [ "$DISTRIBUTION" = "Ubuntu" ]; then
  OS="Debian"
elif [ -f /etc/redhat-release ] || [ "$DISTRIBUTION" = "RedHat" ] || [ "$DISTRIBUTION" = "CentOS" ] || [ "$DISTRIBUTION" = "Amazon" ] || [ "$DISTRIBUTION" = "Rocky" ] || [ "$DISTRIBUTION" = "AlmaLinux" ]; then
  OS="RedHat"
# Some newer distros like Amazon may not have a redhat-release file
elif [ -f /etc/system-release ] || [ "$DISTRIBUTION" = "Amazon" ]; then
  OS="RedHat"
# Arista is based off of Fedora14/18 but do not have /etc/redhat-release
elif [ -f /etc/Eos-release ] || [ "$DISTRIBUTION" = "Arista" ]; then
  OS="RedHat"
# openSUSE and SUSE use /etc/SuSE-release or /etc/os-release
elif [ -f /etc/SuSE-release ] || [ "$DISTRIBUTION" = "SUSE" ] || [ "$DISTRIBUTION" = "openSUSE" ]; then
  OS="SUSE"
# Mac doesn't have a release file
elif [ -x "$(command -v sw_vers)" ] || [ "$DISTRIBUTION" = "Darwin" ]; then
  #OS="macOS"
  echo "Mac not currently supported"
  exit 1
else
  echo "Distribution not supported"
  exit 1
fi
echo "$DISTRIBUTION detected"

# Arch Detection
if [ "$(uname -m)" = "x86_64" ]; then
  ARCH=amd64
elif [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
  ARCH=arm64
elif [ "$(uname -m)" = "armv6l" ] || [ "$(uname -m)" = "armv6" ] && [ $OS != "macOS" ]; then
  ARCH=armv6
elif [ "$(uname -m)" = "armv7l" ] || [ "$(uname -m)" = "armv7" ] && [ $OS != "macOS" ]; then
  ARCH=armv7
else
  ARCH=unsupported
fi

# Remove old Grafana Agent Flow
if [ "$WARM" != true ]; then
  if systemctl list-units --type=service | grep -q grafana-agent-flow; then
    while true; do
      echo "grafana-agent-flow found. This service is no longer used in this version of the Observability Agent. Would you like to uninstall it? (y/n)"
      read -r ans
      ans=${ans,,}
      if [ "$ans" = "y" ]; then
        echo "Uninstalling grafana-agent-flow"
        systemctl stop grafana-agent-flow
        if [ "$OS" = "Debian" ]; then
          apt-get -y remove grafana-agent-flow
          rm -i /etc/apt/sources.list.d/grafana.list
        elif [ "$OS" = "RedHat" ]; then
          dnf -y remove grafana-agent-flow
          rm -i /etc/yum.repos.d/rpm.grafana.repo
        elif [ "$OS" = "SUSE" ]; then
          zypper remove -y grafana-agent-flow
          zypper removerepo grafana
        fi
        systemctl daemon-reload
        echo "Uninstall Complete"
        break
      elif [ "$ans" = "n" ]; then
        break
      else
        echo "Invalid input. Please enter y or n."
      fi
    done
  fi
fi

# Bootstrap
# Update the package manager
if [ "$OS" = "Debian" ]; then
  apt update
elif [ "$OS" = "RedHat" ]; then
  yum update
elif [ "$OS" = "SUSE" ]; then
  zypper update
fi

# Check if curl is installed
if ! which curl >/dev/null; then
    if [ "$OS" = "Debian" ]; then
      echo "Installing curl..."
      apt -y install curl
    elif [ "$OS" = "RedHat" ]; then
      echo "Installing curl..."
      yum -y install curl
    elif [ "$OS" = "SUSE" ]; then
      echo "Installing curl..."
      zypper install -y curl
    elif [ "$OS" = "macOS" ]; then
      echo "curl required"
      exit 1
    else
      echo "OS not supported"
      exit 1
    fi
fi

# Check if iproute2 is installed (required for ss command)
if ! which ss >/dev/null; then
    if [ "$OS" = "Debian" ]; then
      echo "Installing iproute2..."
      apt -y install iproute2
    elif [ "$OS" = "RedHat" ]; then
      echo "Installing iproute2..."
      yum -y install iproute2
    elif [ "$OS" = "SUSE" ]; then
      echo "Installing iproute2..."
      zypper install -y iproute2
    elif [ "$OS" = "macOS" ]; then
      echo "iproute2mac required"
      exit 1
    else
      echo "OS not supported"
      exit 1
    fi
fi

if [ "$WARM" = true ]; then
  echo "Dependencies installed"
  exit 0
fi

if [ "$INSTALL" != false ]; then
  echo "Installing Grafana Alloy..."
  if [ "$OS" = "macOS" ]; then
    if [ "$ARCH" != "unsupported" ]; then
      echo "Downloading binary..."
      # download the binary
      curl -O -L "https://github.com/grafana/alloy/releases/download/v1.2.0/alloy-darwin-$ARCH.zip"
      # extract the binary
      unzip "alloy-darwin-$ARCH.zip"
      # make sure it is executable
      chmod a+x "alloy-darwin-$ARCH"
      binLocation="$(pwd)/alloy-darwin-$ARCH"
      # echo the location of the binary
      echo "Binary location: $binLocation"
      asBinary=true
    else
      echo "Architecture not supported"
      exit 1;
    fi
  else
    if [ "$OS" = "Debian" ]; then
      if [ "$ARCH" != "unsupported" ]; then
        curl -O -L "https://github.com/grafana/alloy/releases/download/v1.2.0/alloy-1.2.0-1.$ARCH.deb"
        dpkg -i "alloy-1.2.0-1.$ARCH.deb"
      else
        echo "Architecture not supported"
        exit 1;
      fi

    elif [ "$OS" = "RedHat" ] || [ "$OS" = "SUSE" ]; then
      if [ "$ARCH" != "unsupported" ]; then
        curl -O -L "https://github.com/grafana/alloy/releases/download/v1.2.0/alloy-1.2.0-1.$ARCH.rpm"
        rpm -i "alloy-1.2.0-1.$ARCH.rpm"
        #change after config updated
      else
        echo "Architecture not supported"
        exit 1;
      fi
    else
      echo "OS not supported, downloading Linux binary..."
      # Download the binary
      # Can't install jq if OS is unknown, therefore can't get latest binary
      curl -O -L "https://github.com/grafana/alloy/releases/download/v1.2.0/alloy-linux-$ARCH.zip"
      # extract the binary
      unzip "alloy-linux-$ARCH.zip"
      # make sure it is executable
      chmod a+x "alloy-linux-$ARCH.zip"
      binLocation="$(pwd)/alloy-linux-$ARCH.zip"
      # echo the location of the binary
      echo "Binary location: $binLocation"
      asBinary=true
    fi
  fi
  echo "Grafana Alloy Installed"
fi

#Check if an env file exists and source it
if [ -f ".env" ]; then
    source .env
    echo "Environment file found"
fi

# Check if the configuration file exists
if [ -n "$CONFIG" ]; then
  echo "Config file found"
  #backup config
  cp -bp "$CONFIG" "$CONFIG.bak"
else
    echo "No pre-existing config file found"
    CONFIG=config.alloy
    echo "Creating configuration file: $CONFIG"
fi

# Get API key
if [ -z "${api_key}" ]; then
  echo "API key not found"
  if [ "$PROMPT" != false ]; then
      # Prompt for API key
      echo "Enter your API key:"
      read -r key
  fi
else
  echo "API key found"
  key="${api_key}"
fi

if [ -z "$key" ]; then
  echo "API key not set"
  exit 1
fi

if [ -n "${metrics_endpoint}" ]; then
  metricsEndpoint="$metrics_endpoint"
else
  metricsEndpoint="https://api.fusionreactor.io/v1/metrics"
fi

# Create config file
# Enable prometheus remote write component and logging component
cat <<EOF > "$CONFIG"
prometheus.remote_write "default" {
	endpoint {
      url = "$metricsEndpoint"
          basic_auth {
              password = "$key"
          }
	}
}

logging {
  level  = "debug"
  format = "logfmt"
}

EOF
echo "Prometheus remote write component enabled"

# Enable node exporter component
cat <<EOF >> "$CONFIG"
prometheus.exporter.unix "example" {

}

prometheus.scrape "unix" {
	targets    = prometheus.exporter.unix.example.targets
	forward_to = [prometheus.remote_write.default.receiver]
}

EOF
echo "Node exporter component enabled"

# Enable log collection
while true; do
    if [ "$PROMPT" != false ] && [ -z "${log_collection}" ]; then
      echo "Is there a service you want to enable log collection for? (y/n)"
      read -r ans
      ans=${ans,,}
    elif [ "${log_collection}" = true ]; then
      ans="y"
    else
      ans="n"
    fi

  if [ "$ans" = "y" ]; then
    if [ "$PROMPT" != false ] && [ -z "${service_name}" ]; then
      echo "Enter the service name: "
      read -r job
    elif [ -n "${service_name}" ]; then
      job="${service_name}"
    else
      echo "Service name not set"
    fi

    if [ "$PROMPT" != false ] && [ -z "${log_path}" ]; then
      echo "Enter the path to the log file: "
      read -r path
    elif [ -n "${log_path}" ]; then
      path="${log_path}"
    else
      echo "Log path not set"
    fi

    if [ -n "${logs_endpoint}" ]; then
      logsEndpoint="$logs_endpoint"
    else
      logsEndpoint="https://api.fusionreactor.io/v1/logs"
    fi

    # Add log collection
    cat <<EOF >> "$CONFIG"
local.file_match "varlog" {
  path_targets = [
    {__path__ = "$path", job = "$job"},
  ]
}

loki.source.file "httpd" {
  targets    = local.file_match.varlog.targets
  forward_to = [loki.write.lokiEndpoint.receiver]
}

loki.write "lokiEndpoint" {
  endpoint {
    url = "$logsEndpoint"
    basic_auth {
        username = "$logUser"
            password = "$key"
        }
  }
}

EOF
    break
  elif [ "$ans" = "n" ]; then
    break
  else
    echo "Invalid input. Please enter y or n."
  fi
done

# Enable open telemetry metrics and traces
while true; do
    if [ "$PROMPT" != false ] && [ -z "${otel_collection}" ]; then
      echo "Would you like to enable collection of open telemetry metrics and traces? (y/n)"
      read -r ans
      ans=${ans,,}
    elif [ "${otel_collection}" = true ]; then
      ans="y"
    else
      ans="n"
    fi

  if [ "$ans" = "y" ]; then
    # Add open telemetry traces
    cat <<EOF >> "$CONFIG"
otelcol.receiver.otlp "default" {
    http {
        endpoint = "0.0.0.0:4318"
    }
    output {
           metrics = [otelcol.exporter.prometheus.default.input]
           traces = [otelcol.processor.batch.default.input]
    }
}

otelcol.processor.batch "default" {
  send_batch_size = 100000
  output {
    traces  = [otelcol.exporter.otlphttp.traceEndpoint.input]
  }
}

otelcol.exporter.prometheus "default" {
    forward_to = [prometheus.remote_write.default.receiver]
}

otelcol.exporter.otlphttp "traceEndpoint" {
    client {
        endpoint = "https://api.fusionreactor.io"
        headers = {authorization = "$key"}
        compression = "none"
    }
}

EOF
    break
  elif [ "$ans" = "n" ]; then
    break
  else
    echo "Invalid input. Please enter y or n."
  fi
done

# Detect MySQL
if { (ss -ltn | grep -qE :3306) || [ -n "${mysql_connection_string}" ]; } && [ "${mysql_disabled}" != true ]; then
  echo "MySQL detected"
  # Check if connection string already set in environment
  if [ -z "${mysql_connection_string}" ]; then
    # Check if credentials already set in environment
    if { [ -z "${mysql_user}" ] || [ -z "${mysql_password}" ]; } && [ "$PROMPT" != false ]; then
      echo "MySQL credentials not found"
      while true; do
          echo "Enter your username:"
          read -r user
          if [ -z "$user" ]; then
              echo "Username cannot be empty. Please enter a valid username."
          else
            break
          fi
      done

      while true; do
          echo "Enter your password:"
          read -rs pass
          if [ -z "$pass" ]; then
              echo "Password cannot be empty. Please enter a valid password."
          else
            break
          fi
      done

      cat <<EOF >> "$CONFIG"
prometheus.exporter.mysql "example" {
  data_source_name = "$user:$pass@(127.0.0.1:3306)/"
}

prometheus.scrape "mysql" {
  targets    = prometheus.exporter.mysql.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    elif [ "${mysql_user}" ] && [ "${mysql_password}" ]; then
      echo "MySQL credentials found"
      cat <<EOF >> "$CONFIG"
prometheus.exporter.mysql "example" {
  data_source_name = "$mysql_user:$mysql_password@(127.0.0.1:3306)/"
}

prometheus.scrape "mysql" {
  targets    = prometheus.exporter.mysql.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    else
      echo "MySQL credentials not found"
    fi
  else
    cat <<EOF >> "$CONFIG"
prometheus.exporter.mysql "example" {
  data_source_name = "$mysql_connection_string"
}

prometheus.scrape "mysql" {
  targets    = prometheus.exporter.mysql.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  fi
  echo "MySQL integration enabled"
fi

# Detect MSSQL
if { (ss -ltn | grep -qE :1433) || [ -n "${mssql_connection_string}" ]; } && [ "${mssql_disabled}" != true ]; then
  echo "MSSQL detected"
  # Check if connection string already set in environment
  if [ -z "${mssql_connection_string}" ]; then
    # Check if credentials already set in environment
    if { [ -z "${mssql_user}" ] || [ -z "${mssql_password}" ]; } && [ "$PROMPT" != false ]; then
      echo "MSSQL credentials not found"
      while true; do
          echo "Enter your username:"
          read -r user
          if [ -z "$user" ]; then
              echo "Username cannot be empty. Please enter a valid username."
          else
            break
          fi
      done

      while true; do
          echo "Enter your password:"
          read -rs pass
          if [ -z "$pass" ]; then
              echo "Password cannot be empty. Please enter a valid password."
          else
            break
          fi
      done

      cat <<EOF >> "$CONFIG"
prometheus.exporter.mssql "example" {
  connection_string = "sqlserver://$user:$pass@127.0.0.1:1433"
}

prometheus.scrape "mssql" {
  targets    = prometheus.exporter.mssql.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    elif [ "${mssql_user}" ] && [ "${mssql_password}" ]; then
      echo "MSSQL credentials found";
      cat <<EOF >> "$CONFIG"
prometheus.exporter.mssql "example" {
  connection_string = "sqlserver://$mssql_user:$mssql_password@127.0.0.1:1433"
}

prometheus.scrape "mssql" {
  targets    = prometheus.exporter.mssql.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    else
      echo "MSSQL credentials not found"
    fi
  else
    cat <<EOF >> "$CONFIG"
prometheus.exporter.mssql "example" {
  connection_string = "$mssql_connection_string"
}

prometheus.scrape "mssql" {
  targets    = prometheus.exporter.mssql.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  fi
  echo "MSSQL integration enabled"
fi

# Detect Postgres
if { (ss -ltn | grep -qE :5432) || [ -n "${postgres_connection_string}" ]; } && [ "${postgres_disabled}" != true ]; then
  echo "Postgres detected"
  # Check if connection string already set in environment
  if [ -z "${postgres_connection_string}" ]; then
    # Check if credentials already set in environment
    if { [ -z "${postgres_user}" ] || [ -z "${postgres_password}" ]; } && [ "$PROMPT" != false ]; then
      echo "Postgres credentials not found"
      while true; do
          echo "Enter your username:"
          read -r user
          if [ -z "$user" ]; then
              echo "Username cannot be empty. Please enter a valid username."
          else
            break
          fi
      done

      while true; do
          echo "Enter your password:"
          read -rs pass
          if [ -z "$pass" ]; then
              echo "Password cannot be empty. Please enter a valid password."
          else
            break
          fi
      done

      cat <<EOF >> "$CONFIG"
prometheus.exporter.postgres "example" {
    data_source_names = ["postgresql://$user:$pass@127.0.0.1:5432/postgres?sslmode=disable"]
    autodiscovery {
        enabled = true
    }
}

prometheus.scrape "postgres" {
  targets    = prometheus.exporter.postgres.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    elif [ "${postgres_user}" ] && [ "${postgres_password}" ]; then
      echo "Postgres credentials found";
      cat <<EOF >> "$CONFIG"
prometheus.exporter.postgres "example" {
    data_source_names = ["postgresql://$postgres_user:$postgres_password@127.0.0.1:5432/postgres?sslmode=disable"]
    autodiscovery {
        enabled = true
    }
}

prometheus.scrape "postgres" {
  targets    = prometheus.exporter.postgres.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    else
      echo "Postgres credentials not found"
    fi
  else
    cat <<EOF >> "$CONFIG"
prometheus.exporter.postgres "example" {
    data_source_names = ["$postgres_connection_string"]
    autodiscovery {
        enabled = true
    }
}

prometheus.scrape "postgres" {
  targets    = prometheus.exporter.postgres.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  fi
  echo "Postgres integration enabled"
fi

# Detect RabbitMQ
if { (ss -ltn | grep -qE :5672) || [ -n "${rabbitmq_scrape_target}" ]; } && [ "${rabbitmq_disabled}" != true ]; then
  echo "RabbitMQ detected"
  if ! (ss -ltn | grep -qE :15692); then
    echo "RabbitMQ exporter is not enabled, see the Observability Agent docs to learn how to enable it"
  fi
  instance_label=${rabbitmq_instance_label:=${rabbitmq_scrape_target:="127.0.0.1:15692"}}
  if [ -n "${rabbitmq_scrape_target}" ]; then
    cat <<EOF >> "$CONFIG"
prometheus.scrape "rabbit" {
targets = [
  {"__address__" = "$rabbitmq_scrape_target", "instance" = "${instance_label}"},
]

forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  else
    cat <<EOF >> "$CONFIG"
prometheus.scrape "rabbit" {
targets = [
  {"__address__" = "127.0.0.1:15692", "instance" = "${instance_label}"},
]

forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  fi
  echo "RabbitMQ scrape endpoint added"
fi

# Detect Redis
if { (ss -ltn | grep -qE :6379) || [ -n "${redis_connection_string}" ]; } && [ "${redis_disabled}" != true ]; then
  echo "Redis detected"
  # Check if connection string already set in environment
  if [ -z "${redis_connection_string}" ]; then
    cat <<EOF >> "$CONFIG"
prometheus.exporter.redis "example" {
  redis_addr = "127.0.0.1:6379"
}

prometheus.scrape "redis" {
  targets    = prometheus.exporter.redis.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  else
    cat <<EOF >> "$CONFIG"
prometheus.exporter.redis "example" {
  redis_addr = "$redis_connection_string"
}

prometheus.scrape "redis" {
  targets    = prometheus.exporter.redis.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  fi
  echo "Redis integration enabled"
fi

# Detect Kafka
if { (ss -ltn | grep -qE :9092) || [ -n "${kafka_connection_string}" ]; } && [ "${kafka_disabled}" != true ]; then
  echo "Kafka detected"
  # Check if connection string already set in environment
  if [ -z "${kafka_connection_string}" ]; then
    cat <<EOF >> "$CONFIG"
prometheus.exporter.kafka "example" {
  kafka_uris = ["127.0.0.1:9092"]
}

prometheus.scrape "kafka" {
  targets    = prometheus.exporter.kafka.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  else
        cat <<EOF >> "$CONFIG"
prometheus.exporter.kafka "example" {
  kafka_uris = ["${kafka_connection_string}"]
}

prometheus.scrape "kafka" {
  targets    = prometheus.exporter.kafka.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  fi
  echo "Kafka integration enabled"
fi

# Detect Elasticsearch
if { (ss -ltn | grep -qE :9200) || [ -n "${elasticsearch_connection_string}" ]; } && [ "${elasticsearch_disabled}" != true ]; then
  echo "Elasticsearch detected"
  if [ -z "${elasticsearch_connection_string}" ]; then
    # Check if credentials already set in environment
    if { [ -z "${elasticsearch_user}" ] || [ -z "${elasticsearch_password}" ]; } && [ "$PROMPT" != false ]; then
      echo "Elasticsearch credentials not found"

      while true; do
          echo "Enter your username:"
          read -r user
          if [ -z "$user" ]; then
              echo "Username cannot be empty. Please enter a valid username."
          else
            break
          fi
      done

      while true; do
          echo "Enter your password:"
          read -rs pass
          if [ -z "$pass" ]; then
              echo "Password cannot be empty. Please enter a valid password."
          else
            break
          fi
      done

      cat <<EOF >> "$CONFIG"
prometheus.exporter.elasticsearch "example" {
  address = "http://$user:$pass@localhost:9200"
}

prometheus.scrape "elasticsearch" {
  targets    = prometheus.exporter.mysql.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    elif [ "${elasticsearch_user}" ] && [ "${elasticsearch_password}" ]; then
      echo "Elasticsearch credentials found";
      cat <<EOF >> "$CONFIG"
prometheus.exporter.elasticsearch "example" {
  address = "http://$elasticsearch_user:$elasticsearch_password@localhost:9200"
}

prometheus.scrape "elasticsearch" {
  targets    = prometheus.exporter.mysql.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    else
      echo "Elasticsearch credentials not found"
    fi
  else
    cat <<EOF >> "$CONFIG"
prometheus.exporter.elasticsearch "example" {
  address = "$elasticsearch_connection_string"
}

prometheus.scrape "elasticsearch" {
  targets    = prometheus.exporter.elasticsearch.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  fi
  echo "Elasticsearch integration enabled"
fi

# Detect Mongo
if { (ss -ltn | grep -qE :27017) || [ -n "${mongodb_connection_string}" ]; } && [ "${mongodb_disabled}" != true ]; then
  echo "MongoDB detected"
  if [ -z "${mongodb_connection_string}" ]; then
    # Check if credentials already set in environment
    if { [ -z "${mongodb_user}" ] || [ -z "${mongodb_password}" ]; } && [ "$PROMPT" != false ]; then
      echo "MongoDB credentials not found"

      while true; do
          echo "Enter your username:"
          read -r user
          if [ -z "$user" ]; then
              echo "Username cannot be empty. Please enter a valid username."
          else
            break
          fi
      done

      while true; do
          echo "Enter your password:"
          read -rs pass
          if [ -z "$pass" ]; then
              echo "Password cannot be empty. Please enter a valid password."
          else
            break
          fi
      done

      cat <<EOF >> "$CONFIG"
prometheus.exporter.mongodb "example" {
  mongodb_uri = "mongodb://$user:$pass@127.0.0.1:27017/"
}

prometheus.scrape "mongodb" {
  targets    = prometheus.exporter.mongodb.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    elif [ "${mongodb_user}" ] && [ "${mongodb_password}" ]; then
      echo "MongoDB credentials found";
      cat <<EOF >> "$CONFIG"
prometheus.exporter.mongodb "example" {
  mongodb_uri = "mongodb://$mongodb_user:$mongodb_password@127.0.0.1:27017/"
}

prometheus.scrape "mongodb" {
  targets    = prometheus.exporter.mongodb.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    else
      echo "MongoDB credentials not found"
    fi
  else
    cat <<EOF >> "$CONFIG"
prometheus.exporter.mongodb "example" {
  mongodb_uri = "$mongodb_connection_string"
}

prometheus.scrape "mongodb" {
  targets    = prometheus.exporter.mongodb.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  fi
  echo "MongoDB integration enabled"
fi

# Detect OracleDB
if { (ss -ltn | grep -qE :1521) || [ -n "${oracledb_connection_string}" ]; } && [ "${oracledb_disabled}" != true ]; then
  echo "OracleDB detected"
  if [ -z "${oracledb_connection_string}" ]; then
    # Check if credentials already set in environment
    if { [ -z "${oracledb_user}" ] || [ -z "${oracledb_password}" ]; } && [ "$PROMPT" != false ]; then
      echo "OracleDB credentials not found"

      while true; do
          echo "Enter your username:"
          read -r user
          if [ -z "$user" ]; then
              echo "Username cannot be empty. Please enter a valid username."
          else
            break
          fi
      done

      while true; do
          echo "Enter your password:"
          read -rs pass
          if [ -z "$pass" ]; then
              echo "Password cannot be empty. Please enter a valid password."
          else
            break
          fi
      done

      cat <<EOF >> "$CONFIG"
prometheus.exporter.oracledb "example" {
  connection_string = "oracle://$user:$pass@127.0.0.1:1521/ORCLCDB"
}

prometheus.scrape "oracledb" {
  targets    = prometheus.exporter.oracledb.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    elif [ "${oracledb_user}" ] && [ "${oracledb_password}" ]; then
      echo "OracleDB credentials found";
      cat <<EOF >> "$CONFIG"
prometheus.exporter.oracledb "example" {
  connection_string = "oracle://$oracledb_user:$oracledb_password@127.0.0.1:1521/ORCLCDB"
}

prometheus.scrape "oracledb" {
  targets    = prometheus.exporter.oracledb.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
    else
      echo "OracleDB credentials not found"
    fi
  else
    cat <<EOF >> "$CONFIG"
prometheus.exporter.oracledb "example" {
  connection_string = "$oracledb_connection_string"
}

prometheus.scrape "oracledb" {
  targets    = prometheus.exporter.oracledb.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  fi
  echo "OracleDB integration enabled"
fi

# Add Additional Endpoints
if [ -n "${scrape_targets}" ]; then
  # Split the variables into arrays
  IFS=", " read -ra scrapeTargets <<< "${scrape_targets//\"/}"

  # Add the jobs and targets to the config
  cat <<EOF >> "$CONFIG"
prometheus.scrape "endpoints" {
  targets = [
EOF
  for i in "${!scrapeTargets[@]}"; do
    cat <<EOF >> "$CONFIG"
      {"__address__" = "${scrapeTargets[i]}"},
EOF
  done
  cat <<EOF >> "$CONFIG"
  ]
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
  echo "Scrape endpoints added"
fi

if [ "$PROMPT" != false ]; then
  cat <<EOF >> "$CONFIG"
prometheus.scrape "endpoints" {
  targets = [
EOF
  while true; do
      echo "Is there an additional endpoint you would like to scrape? (y/n)"
      read -r ans
      ans=${ans,,}
      if [ "$ans" = "y" ]; then
        echo "Enter the target to be scraped: "
        read -r scrapeTarget
        if [ -z "$scrapeTarget" ]; then
          echo "Fields cannot be empty"
        else
          cat <<EOF >> "$CONFIG"
    {"__address__" = "$scrapeTarget"},
EOF
        fi
      elif [ "$ans" = "n" ]; then
        break
      else
        echo "Invalid input. Please enter y or n."
      fi
  done
  cat <<EOF >> "$CONFIG"
  ]
  forward_to = [prometheus.remote_write.default.receiver]
}

EOF
fi

echo "Config file updated";

if [ "${asBinary}" = true ]; then
  echo "Grafana Alloy was downloaded as a binary so it will have to be started manually"
  echo "To run the binary, run: $binLocation --config.file $CONFIG"

# If prompt flag is used, it's running in Docker (we don't need to move files or restart the agent for docker)
elif [ "$PROMPT" != false ] || [ "${start_service}" = true ]; then
  mv $CONFIG /etc/alloy/config.alloy
  echo "Config file can be found at /etc/alloy/config.alloy"
  systemctl enable alloy.service
  echo "Grafana Alloy enabled"
  systemctl start alloy.service
  echo "Grafana Alloy started"
fi