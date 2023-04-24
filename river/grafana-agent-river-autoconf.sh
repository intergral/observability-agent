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
        true)
          INSTALL=true
          ;;
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
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

#Arch Detection
if [[ `uname -m` == "x86_64" ]]; then
  ARCH=amd64
elif [[ `uname -m` == "aarch64" ]] || [[ `uname -m` == "arm64" ]]; then
  ARCH=arm64
elif [[ `uname -m` == "armv6l" ]] || [[ `uname -m` == "armv6" ]]; then
  ARCH=armv6
elif [[ `uname -m` == "armv7l" ]] || [[ `uname -m` == "armv7" ]]; then
  ARCH=armv7
else
  ARCH=unsupported
fi

# OS/Distro Detection
# Try lsb_release, fallback with /etc/issue then uname command
KNOWN_DISTRIBUTION="(Debian|Ubuntu|RedHat|CentOS|openSUSE|Amazon|Arista|SUSE|Rocky|AlmaLinux)"
DISTRIBUTION=$(lsb_release -d 2>/dev/null | grep -Eo $KNOWN_DISTRIBUTION  || grep -Eo $KNOWN_DISTRIBUTION /etc/issue 2>/dev/null || grep -Eo $KNOWN_DISTRIBUTION /etc/Eos-release 2>/dev/null || grep -m1 -Eo $KNOWN_DISTRIBUTION /etc/os-release 2>/dev/null || uname -s)

if [ -f /etc/debian_version ] || [ "$DISTRIBUTION" == "Debian" ] || [ "$DISTRIBUTION" == "Ubuntu" ]; then
    OS="Debian"
    echo "$DISTRIBUTION detected"
elif [ -f /etc/redhat-release ] || [ "$DISTRIBUTION" == "RedHat" ] || [ "$DISTRIBUTION" == "CentOS" ] || [ "$DISTRIBUTION" == "Amazon" ] || [ "$DISTRIBUTION" == "Rocky" ] || [ "$DISTRIBUTION" == "AlmaLinux" ]; then
    OS="RedHat"
# Some newer distros like Amazon may not have a redhat-release file
elif [ -f /etc/system-release ] || [ "$DISTRIBUTION" == "Amazon" ]; then
    OS="RedHat"
# Arista is based off of Fedora14/18 but do not have /etc/redhat-release
elif [ -f /etc/Eos-release ] || [ "$DISTRIBUTION" == "Arista" ]; then
    OS="RedHat"
# openSUSE and SUSE use /etc/SuSE-release or /etc/os-release
elif [ -f /etc/SuSE-release ] || [ "$DISTRIBUTION" == "SUSE" ] || [ "$DISTRIBUTION" == "openSUSE" ]; then
    OS="SUSE"

else
  echo "Distribution not supported"
fi

if [[ "$INSTALL" != false ]]; then
  # Install as service prompt
  while true; do
    echo "Would you like to install the agent as a service? (y/n) "
    read -r ans
    ans=${ans,,}
    if [ "$ans" = "y" ]; then

      if [ "$OS" = "Debian" ]; then
        if [ "$ARCH" != "unsupported" ]; then
          sudo apt install jq
          DOWNLOAD_URL=$(curl -s https://api.github.com/repos/grafana/agent/releases/latest | jq ".assets[] | select(.name|match(\"$ARCH.deb$\")) | .browser_download_url" | tr -d '"')
          curl -LO "$DOWNLOAD_URL"
          sudo dpkg -i "$(basename "$DOWNLOAD_URL")"
          #systemctl start grafana-agent.service
        else
          echo "Architecture not supported"
          exit 1;
        fi

      elif [ "$OS" = "RedHat" ] || [ "$OS" = "SUSE" ]; then
        if [ "$ARCH" != "unsupported" ]; then
          if [ "$OS" = "RedHat" ]; then
            sudo yum install jq
          elif [ "$OS" = "SUSE" ]; then
            sudo zypper install jq
          fi
          DOWNLOAD_URL=$(curl -s https://api.github.com/repos/grafana/agent/releases/latest | jq ".assets[] | select(.name|match(\"$ARCH.rpm$\")) | .browser_download_url" | tr -d '"')
          curl -LO "$DOWNLOAD_URL"
          sudo rpm -i "$(basename "$DOWNLOAD_URL")"
          systemctl start grafana-agent.service
        else
          echo "Architecture not supported"
          exit 1;
        fi

      else
        echo "OS not supported, downloading binary..."
        # Download the binary
        # Can't install jq if OS is unknown, therefore can't get latest binary
        curl -LO "https://github.com/grafana/agent/releases/download/v0.32.1/grafana-agent-linux-$ARCH.zip"
        # extract the binary
        unzip "grafana-agent-linux-$ARCH.zip"
        # make sure it is executable
        chmod a+x "grafana-agent-linux-$ARCH"
        # echo the location of the binary
        echo "Binary location: $(pwd)/grafana-agent-linux-$ARCH"
      fi
      break
    elif [ "$ans" = "n" ]; then
      echo "Downloading binary..."
      # download the binary
      # Can't install jq if OS is unknown, therefore can't get latest binary
      curl -O -L "https://github.com/grafana/agent/releases/download/v0.32.1/grafana-agent-linux-$ARCH.zip"
      # extract the binary
      unzip "grafana-agent-linux-$ARCH.zip"
      # make sure it is executable
      chmod a+x "grafana-agent-linux-$ARCH"
      # echo the location of the binary
      echo "Binary location: $(pwd)/grafana-agent-linux-$ARCH"
      break
    else
      echo "Invalid input. Please enter y or n."
    fi
  done
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
  #timestamp
else
    echo "No pre-existing config file found"
    CONFIG=grafana-agent.river
    echo "Creating configuration file: $CONFIG"
fi

if [ -z "${fr_api_key}" ]; then
  # Prompt for API key
  echo "API key not found"
  echo "Enter your API key:"
  read -r key
else
  key="${fr_api_key}"
fi

# Enable prometheus remote write component
  cat <<EOF > "$CONFIG"
prometheus.remote_write "default" {
	endpoint {
      url = "https://api.fusionreactor.io/v1/metrics"
          basic_auth {
              password = $key
          }
	}
}

EOF
echo "Prometheus remote write component enabled"

# Enable node exporter component
  cat <<EOF >> "$CONFIG"
prometheus.exporter.unix {
  set_collectors = ["cpu", "diskstats"]
}

EOF
echo "Node exporter component enabled"

# Enable prometheus scrape component
  cat <<EOF >> "$CONFIG"
prometheus.scrape "default" {
	targets    = prometheus.exporter.unix.targets
	forward_to = [prometheus.remote_write.default.receiver]
}

EOF
echo "Prometheus scrape component enabled"

echo "Config file updated";