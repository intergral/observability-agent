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
### Linux
In a terminal, run: </br>
`sudo /bin/bash path/to/observability-agent-autoconf.sh`

### Windows
In a terminal, run: </br>
`path/to/observability-agent-autoconf.ps1`

### Options

Agent installation is enabled by default. To run without installing the agent, add `--install false` to the end of the run command. For example: </br>
`sudo path/to/grafana-agent-autoconf.sh --install false`

To modify a pre-existing config file, add `--config.file`, followed by the path to the file, to the end of the run command. For example: 
`sudo path/to/grafana-agent-autoconf.sh --config.file path/to/configfile`  
A backup of your original file will be created

You can use both `--install` and `--config.file` options in the same run command, order is irrelevant. For example: </br>
`sudo path/to/grafana-agent-autoconf.sh --install false --config.file path/to/config`</br>
or </br>
`sudo path/to/grafana-agent-autoconf.sh --config.file path/to/config --install false`

### Docker
When running in Docker, you will not be prompted for any information. Therefore, you must specify an api key before running. Additionally, you must set the relevant
environment variables for whichever services you have running, so they can be configured. These environment variables can be found in the [Environment Variables](#environment-variables) section

> ⚠️ The agent will not ship to FusionReactor without setting the `fr_api_key` variable

Example for setting environment variables individually: </br>
`docker run --env fr_api_key=1234567890 --env fr_log_collection=true --env fr_service_name=service --env fr_log_path=path docker.io/grafana/agent:main-amd64`

Example for setting environment variables using an env file: </br>
`docker run --env-file env.list docker.io//grafana/agent:main-amd64`

Example for setting environment variables using docker-compose:
```yaml
version: "3.2"

services:
  agent:
    image: intergralgmbh/observability-agent:latest
    environment:
      - fr_api_key=1234567890
      - fr_log_collection=true
      - fr_service_name=service
      - fr_log_path=path
```

For more information please visit the [Docker documentation](https://docs.docker.com/engine/reference/commandline/run/#env)

## Environment Variables
To add integrations without being prompted for credentials, there are several environment variables you can use:

| Variable               | Type     |
|------------------------|----------|
| `fr_api_key`           | `string` |
| `fr_mysql_user`        | `string` |
| `fr_mysql_password`    | `string` |
| `fr_mssql_user`        | `string` |
| `fr_mssql_password`    | `string` |
| `fr_postgres_user`     | `string` |
| `fr_postgres_password` | `string` |

If you wish to enable log collection, the following environment variables must be set:

| Variable            | Type     |
|---------------------|----------|
| `fr_log_collection` | `bool`   |
| `fr_service_name`   | `string` |
| `fr_log_path`       | `string` |

The default connection strings used in the config file are:

| Integration | Connection String                                                        |
|-------------|--------------------------------------------------------------------------|
| `MySQL`     | `<username>:<password>@(127.0.0.1:3306)/`                                |
| `MSSQL`     | `sqlserver://<username>:<password>@1433:1433`                            |
| `Postgres`  | `postgresql://<username>:<password>@127.0.0.1:5432/shop?sslmode=disable` |

To replace these with a custom connection string, there are several environment variables you can use:

| Variable                        | Type     |
|---------------------------------|----------|
| `fr_mysql_connection_string`    | `string` |
| `fr_mssql_connection_string`    | `string` |
| `fr_postgres_connection_string` | `string` |

If there is a service running that you don't want to enable the integration for, you can use the relevant environment variable from the following options
to disable it by default when creating the configuration:

| Variable               | Type   |
|------------------------|--------|
| `fr_mysql_disabled`    | `bool` |
| `fr_mssql_disabled`    | `bool` |
| `fr_postgres_disabled` | `bool` |

If you wish to use an environment file to set environment variables, rather than setting them as system environment variables,
you can do so by naming the file ".env" and placing it in the same directory as the "grafana-agent-autoconf" script.