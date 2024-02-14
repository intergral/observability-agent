#!/bin/sh

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
else
  echo "Distribution not supported"
  exit 0
fi
echo "$OS detected"


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
