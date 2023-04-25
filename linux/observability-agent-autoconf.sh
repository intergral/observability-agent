#!/bin/sh
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
  OS="macOS"
  echo "Mac not currently supported"
  exit 1
else
  echo "Distribution not supported"
  exit 1
fi
echo "$DISTRIBUTION detected"

#Arch Detection
if [ "$(uname -m)" = "x86_64" ]; then
  ARCH=amd64
elif [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
  ARCH=arm64
elif [ "$(uname -m)" = "armv6l" ] || [ "$(uname -m)" = "armv6" ]; then
  ARCH=armv6
elif [ "$(uname -m)" = "armv7l" ] || [ "$(uname -m)" = "armv7" ]; then
  ARCH=armv7
else
  ARCH=unsupported
fi

# Only amd64 and arm64 available for mac
if { [ $ARCH = armv6 ] || [ $ARCH = armv6 ]; } && [ $OS = "macOS" ]; then
  ARCH=unsupported
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
    echo "Installing curl..."
    if [ "$OS" = "Debian" ]; then
      apt -y install curl
    elif [ "$OS" = "RedHat" ]; then
      yum -y install curl
    elif [ "$OS" = "SUSE" ]; then
      zypper -y install curl
    elif [ "$OS" = "macOS" ]; then
      echo "curl required"
      exit 1
    else
      echo "OS not supported"
      exit 1
    fi
fi

# Check if tar is installed
if ! which tar >/dev/null; then
    echo "Installing tar..."
    if [ "$OS" = "Debian" ]; then
      apt -y install tar
    elif [ "$OS" = "RedHat" ]; then
      yum -y install tar
    elif [ "$OS" = "SUSE" ]; then
      zypper -y install tar
    elif [ "$OS" = "macOS" ]; then
      echo "iproute2mac required"
      exit 1
    else
      echo "OS not supported"
      exit 1
    fi
fi

# Check if iproute2 is installed (required for ss command)
if [ "$OS" = "macOS" ]; then
  if ! which iproute2mac >/dev/null; then
    echo "iproute2mac required"
    exit 1
  fi
else
  if ! which ss >/dev/null; then
      echo "Installing iproute2..."
      if [ "$OS" = "Debian" ]; then
        apt -y install iproute2
      elif [ "$OS" = "RedHat" ]; then
        yum -y install iproute2
      elif [ "$OS" = "SUSE" ]; then
        zypper -y install iproute2
      else
        echo "OS not supported"
        exit 1
      fi
  fi
fi


# Check if jq is installed
if ! which jq >/dev/null; then
    echo "Installing jq..."
    if [ "$OS" = "Debian" ]; then
      apt -y install jq
    elif [ "$OS" = "RedHat" ]; then
      yum -y install jq
    elif [ "$OS" = "SUSE" ]; then
      zypper -y install jq
    elif [ "$OS" = "macOS" ]; then
      echo "jq required"
      exit 1
    else
      echo "OS not supported"
      exit 1
    fi
fi

# Check if yq is installed to edit config
if ! which yq >/dev/null; then
  if [ "$OS" = "macOS" ]; then
    sys="darwin"
  else
    sys="linux"
  fi

  DOWNLOAD_URL=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq ".assets[] | select(.name|match(\"$sys""_$ARCH.tar.gz$\")) | .browser_download_url" | tr -d '"')
  echo "Installing yq..."
  curl -LO "$DOWNLOAD_URL"
  tar -xvf "$(basename "$DOWNLOAD_URL")" --exclude 'yq.1' --exclude 'install-man-page.sh' >/dev/null
  mv yq_${sys}_${ARCH} /usr/local/bin/yq
  chmod +x /usr/local/bin/yq
fi

if [ "$WARM" = true ]; then
  echo "Dependencies installed"
  exit 0
fi

if [ "$INSTALL" != false ]; then
  echo "Installing Grafana agent..."
  if [ "$OS" = "macOS" ]; then
    if [ "$ARCH" != "unsupported" ]; then
      echo "Downloading binary..."
      # download the binary
      DOWNLOAD_URL=$(curl -s https://api.github.com/repos/grafana/agent/releases/latest | jq ".assets[] | select(.name|match(\"agent-darwin-$ARCH.zip$\")) | .browser_download_url" | tr -d '"')
      curl -LO "$DOWNLOAD_URL"
      # extract the binary
      unzip "grafana-agent-darwin-$ARCH.zip"
      # make sure it is executable
      chmod a+x "grafana-agent-darwin-$ARCH"
      binLocation="$(pwd)/grafana-agent-darwin-$ARCH"
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
        DOWNLOAD_URL=$(curl -s https://api.github.com/repos/grafana/agent/releases/latest | jq ".assets[] | select(.name|match(\"$ARCH.deb$\")) | .browser_download_url" | tr -d '"')
        curl -LO "$DOWNLOAD_URL"
        dpkg -i "$(basename "$DOWNLOAD_URL")"
      else
        echo "Architecture not supported"
        exit 1;
      fi

    elif [ "$OS" = "RedHat" ] || [ "$OS" = "SUSE" ]; then
      if [ "$ARCH" != "unsupported" ]; then
        DOWNLOAD_URL=$(curl -s https://api.github.com/repos/grafana/agent/releases/latest | jq ".assets[] | select(.name|match(\"$ARCH.rpm$\")) | .browser_download_url" | tr -d '"')
        curl -LO "$DOWNLOAD_URL"
        rpm -i "$(basename "$DOWNLOAD_URL")"
        #change after config updated
      else
        echo "Architecture not supported"
        exit 1;
      fi
    else
      echo "OS not supported, downloading binary..."
      # Download the binary
      # Can't install jq if OS is unknown, therefore can't get latest binary
      curl -O -L "https://github.com/grafana/agent/releases/download/v0.32.1/grafana-agent-linux-$ARCH.zip"
      # extract the binary
      unzip "grafana-agent-linux-$ARCH.zip"
      # make sure it is executable
      chmod a+x "grafana-agent-linux-$ARCH"
      binLocation="$(pwd)/grafana-agent-linux-$ARCH"
      # echo the location of the binary
      echo "Binary location: $binLocation"
      asBinary=true
    fi
  fi
  echo "Grafana Agent installed"
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
    CONFIG=grafana-agent.yaml
    echo "Creating configuration file: $CONFIG"
fi

# Get API key
if [ -z "${fr_api_key}" ]; then
  echo "API key not found"
  if [ "$PROMPT" != false ]; then
      # Prompt for API key
      echo "Enter your API key:"
      read -r key
  fi
else
  key="${fr_api_key}"
fi

# Create config file
cat <<EOF > "$CONFIG"
server:
  log_level: warn
metrics:
  global:
    scrape_interval: 1m
    remote_write:
      - url: https://api.fusionreactor.io/v1/metrics
        authorization:
          credentials: $key
integrations:
  agent:
    enabled: true
  node_exporter:
    enabled: true
    include_exporter_metrics: true
    disable_collectors:
      - "mdadm"
EOF

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

    # Add log collection
    yq -i e '.logs.configs = [{"name": "default", "positions": {"filename": "/tmp/positions.yaml"},
    "clients": [{"url": "https://api.fusionreactor.io/v1/logs", "authorization": {"credentials": "'"$key"'"}}],
    "scrape_configs": [{"job_name": "'"$job"'", "static_configs": [{"targets": ["'"$key"'"], "labels": {"job": "'"$job"'", "host": "localhost", "__path__": "'"$path"'"}}]}]}]' "$CONFIG"
    break
  elif [ "$ans" = "n" ]; then
    break
  else
    echo "Invalid input. Please enter y or n."
  fi
done

# Ensure node exporter is enabled
if [ "$(yq e '.integrations.node_exporter.enabled' "$CONFIG")" != "true" ]; then
    yq -i e '.integrations.node_exporter.enabled |= true | .integrations.node_exporter.include_exporter_metrics |= true | .integrations.node_exporter.disable_collectors = ["mdadm"] | .integrations.node_exporter.disable_collectors[0] style="double"' "$CONFIG"
    echo "Node exporter integration enabled"
fi

# Detect MySQL
if (ss -ltn | grep -qE :3306) || [ -n "${fr_mysql_connection_string}" ]; then
  echo "MySQL detected"
  # Check if connection string already set in environment
  if [ -z "${fr_mysql_connection_string}" ]; then
    # Check if credentials already set in environment
    if { [ -z "${fr_mysql_user}" ] || [ -z "${fr_mysql_password}" ]; } && [ "$PROMPT" != false ]; then
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
      yq -i e '.integrations.mysqld_exporter.enabled |= true, .integrations.mysqld_exporter.data_source_name |= "'"$user"':'"$pass"'@(127.0.0.1:3306)/"' "$CONFIG"
    elif "${fr_mysql_user}" && "${fr_mysql_password}"; then
      echo "MySQL credentials found"
      yq -i e '.integrations.mysqld_exporter.enabled |= true, .integrations.mysqld_exporter.data_source_name |= "'"${fr_mysql_user}"':'"${fr_mysql_password}"'@(127.0.0.1:3306)/"' "$CONFIG"
    else
      echo "MySQL credentials not found"
    fi
  else
    yq -i e '.integrations.mysqld_exporter.enabled |= true, .integrations.mysqld_exporter.data_source_name |= "'"${fr_mysql_connection_string}"'"' "$CONFIG"
  fi
  if [ -n "${fr_mysql_disabled}" ] && [ "${fr_mysql_disabled}" = true ]; then
    yq -i e '.integrations.mysqld_exporter.enabled |= false' "$CONFIG"
    echo "MySQL integration configured"
  else
    echo "MySQL integration enabled"
  fi
fi

# Detect MSSQL
if (ss -ltn | grep -qE :1433) || [ -n "${fr_mssql_connection_string}" ]; then
  echo "MSSQL detected"
  # Check if connection string already set in environment
  if [ -z "${fr_mssql_connection_string}" ]; then
    # Check if credentials already set in environment
    if { [ -z "${fr_mssql_user}" ] || [ -z "${fr_mssql_password}" ]; } && [ "$PROMPT" != false ]; then
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
      yq -i e '.integrations.mssql.enabled |= true, .integrations.mssql.connection_string |= "sqlserver://'"$user"':'"$pass"'@1433:1433" | .integrations.mssql.connection_string style="double"' "$CONFIG"
    elif "${fr_mssql_user}" && "${fr_mssql_password}"; then
      echo "MSSQL credentials found";
      yq -i e '.integrations.mssql.enabled |= true, .integrations.mssql.connection_string |= "sqlserver://'"${fr_mssql_user}"':'"${fr_mssql_password}"'@1433:1433" | .integrations.mssql.connection_string style="double"' "$CONFIG"
    else
      echo "MSSQL credentials not found"
    fi
  else
    yq -i e '.integrations.mssql.enabled |= true, .integrations.mssql.connection_string |= "'"${fr_mssql_connection_string}"'"' "$CONFIG"
  fi
  if [ -n "${fr_mssql_disabled}" ] && [ "${fr_mssql_disabled}" = true ]; then
    yq -i e '.integrations.mssql.enabled |= false' "$CONFIG"
    echo "MSSQL integration configured"
  else
    echo "MSSQL integration enabled"
  fi
fi

# Detect Postgres
if (ss -ltn | grep -qE :5432) || [ -n "${fr_postgres_connection_string}" ]; then
  echo "Postgres detected"
  # Check if connection string already set in environment
  if [ -z "${fr_postgres_connection_string}" ]; then
    # Check if credentials already set in environment
    if { [ -z "${fr_postgres_user}" ] || [ -z "${fr_postgres_password}" ]; } && [ "$PROMPT" != false ]; then
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
      yq -i e '.integrations.postgres_exporter.enabled |= true, .integrations.postgres_exporter.data_source_names |= ["postgresql://'"$user"':'"$pass"'@127.0.0.1:5432/shop?sslmode=disable"] | .integrations.postgres_exporter.data_source_names[0] style="double"' "$CONFIG"
    elif "${fr_postgres_user}" && "${fr_postgres_password}"; then
      echo "Postgres credentials found";
      yq -i e '.integrations.postgres_exporter.enabled |= true, .integrations.postgres_exporter.data_source_names |= ["postgresql://'"${fr_postgres_user}"':'"${fr_postgres_password}"'@127.0.0.1:5432/shop?sslmode=disable"] | .integrations.postgres_exporter.data_source_names[0] style="double"' "$CONFIG"
    else
      echo "Postgres credentials not found"
    fi
  else
    yq -i e '.integrations.postgres_exporter.enabled |= true, .integrations.postgres_exporter.data_source_names |= "'"${fr_postgres_connection_string}"'"' "$CONFIG"
  fi
  if [ -n "${fr_postgres_disabled}" ] && [ "${fr_postgres_disabled}" = true ]; then
    yq -i e '.integrations.postgres_exporter.enabled |= false' "$CONFIG"
    echo "Postgres integration configured"
  else
    echo "Postgres integration enabled"
  fi
fi

echo "Config file updated";

if [ "${asBinary}" = true ]; then
  echo "The Grafana agent was downloaded as a binary so it will have to be started manually"
  echo "To run the binary, run: $binLocation --config.file $CONFIG"
fi