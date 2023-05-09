## Introduction
The Observability Agent autoconfiguration and installer tool is a wrapper for the [Grafana Agent](https://github.com/grafana/agent) that can install the agent,
detect which services are running on your machine, and automatically create a configuration file with integrations for
detected services. A Node/Windows exporter integration will be added by default.

## Prerequisites
For Unix machines, the script will have to be run with root privileges, otherwise you will be prompted for your password during execution.
Windows machines must have Powershell 5.1 or later installed. macOS is not currently supported.

The script will automatically detect what's running on your machine and add integrations to the config file. For this, each service you want to have an integration
for must be running on its default port, these are:

| Integration  | Default Port |
|--------------|--------------|
| `MySQL`      | `3306`       |
| `MSSQL`      | `1433`       |
| `Postgres`   | `5432`       |

## Procedure
[Latest Release](https://github.com/intergral/observability-agent/releases)

### Linux
To download the installer, in a terminal, run: </br>
`curl -O -L "https://github.com/intergral/observability-agent/releases/download/v0.1.0/observability-agent-autoconf.sh"
chmod a+x "observability-agent-autoconf.sh"`

To run the installer, in a terminal, run: </br>
`sudo /bin/bash path/to/observability-agent-autoconf.sh`

### Windows
To run the installer, in a terminal, run: </br>
`path/to/observability-agent-autoconf.ps1`

### Options

Agent installation is enabled by default. To run without installing the agent, add `--install false` to the end of the run command. For example: </br>
`sudo path/to/observability-agent-autoconf.sh --install false`

To modify a pre-existing config file, add `--config.file`, followed by the path to the file, to the end of the run command. For example:
`sudo path/to/observability-agent-autoconf.sh --config.file path/to/configfile`  
A backup of your original file will be created

You can use both `--install` and `--config.file` options in the same run command, order is irrelevant. For example: </br>
`sudo path/to/observability-agent-autoconf.sh --install false --config.file path/to/config`</br>
or </br>
`sudo path/to/observability-agent-autoconf.sh --config.file path/to/config --install false`

### Docker
When running in Docker, you will not be prompted for any information. Therefore, you must specify an api key before running. Additionally, you must set the relevant
environment variables for whichever services you have running, so they can be configured. These environment variables can be found in the [Environment Variables](#environment-variables) section

To run in docker, we provide prebuilt images. See our [Docker Hub](https://hub.docker.com/repository/docker/intergral/observability-agent/general) repository for more information

## Environment Variables
To add integrations without being prompted for credentials, there are several environment variables you can use:

### Ingest

| Variable              | Type     | Description                                                   |
|-----------------------|----------|---------------------------------------------------------------|
| `api_key`             | `string` | API Key to authenticate with your FusionReactor Cloud Account |

To change the endpoints for metrics and logs, you can use these environment variables:

| Variable          | Type     | Default                                   |
|-------------------|----------|-------------------------------------------|
| `metricsEndpoint` | `string` | `https://api.fusionreactor.io/v1/metrics` |
| `logsEndpoint`    | `string` | `https://api.fusionreactor.io/v1/logs`    |

### Metric Exporters

| Variable              | Type     | Description                                                    |
|-----------------------|----------|----------------------------------------------------------------|
| `mysql_user`          | `string` | User for the local Mysql database                              |
| `mysql_password`      | `string` | Password for the local Mysql database                          |
| `mysql_disabled`      | `bool`   | Enables/Disables Mysql the mysql exporter (enabled by default) |
| `mssql_user`          | `string` |                                                                |
| `mssql_password`      | `string` |                                                                |
| `mssql_disabled`      | `bool`   |                                                                |
| `postgres_user`       | `string` |                                                                |
| `postgres_password`   | `string` |                                                                |
| `postgres_disabled`   | `bool`   |                                                                |

### Exporting metrics from external machines

To replace these with a custom connection string, there are several environment variables you can use:

| Variable                       | Type     | Example (Defaults)                                     |
|--------------------------------|----------|--------------------------------------------------------|
| `mysql_connection_string`      | `string` | `<username>:<password>@(<host>:3306)/`                 |
| `mssql_connection_string`      | `string` | `sqlserver://<username>:<password>@<host>:1433`        |
| `postgres_connection_string`   | `string` | `postgresql://<username>:<password>@<host>:5432/shop?` |

### Log Exporters

If you wish to enable log collection, the following environment variables must be set:

| Variable           | Type     | Description                                     |
|--------------------|----------|-------------------------------------------------|
| `log_collection`   | `bool`   | Enables log collection                          |
| `service_name`     | `string` | Set a name for you log collection service       |
| `log_path`         | `string` | Set a file path for your log collection service |

### .Env Files

If you wish to use an environment file to set environment variables, rather than setting them as system environment variables,
you can do so by naming the file ".env" and placing it in the same directory as the "observability-agent-autoconf" script.

Example ".env" file:
```
api_key=1234567890
mysql_connection_string=root:my-secret-pw@(mysql:3306)/
log_collection=true
service_name=service
log_path=path
```