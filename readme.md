## Introduction
The Observability Agent autoconfiguration and installer tool is a wrapper for the [Grafana Agent](https://github.com/grafana/agent) that can install the agent,
detect which services are running on your machine, and automatically create a configuration file with integrations for
detected services. A Node/Windows exporter integration will be added by default.

## Prerequisites
For Unix machines, the script will have to be run with root privileges, otherwise you will be prompted for your password during execution.
Windows machines must have Powershell 5.1 or later installed. macOS is not currently supported.

The script will automatically detect what's running on your machine and add integrations to the config file. For this, each service you want to have an integration
for must be running on its default port, these are:
- MySQL - 3306
- MSSQL - 1433
- Postgres - 5432

## Procedure
### Linux
In a terminal, run:
sudo path/to/grafana-agent-autoconf.sh

### Windows
In a terminal, run:
path/to/grafana-agent-autoconf.ps1

### Docker
When running in Docker, you will not be prompted for any information. Therefore, you must specify an api key before running. Additionally, you must set the relevant
environment variables for whichever services you have running, so they can be configured.

To set the api key the following environment variable must be set:
- fr_api_key

If you wish to enable log collection, the following environment variables
must be set:
- log_collection
- service_name
- log_path

Example for setting environment variables individually:
`docker run --env fr_api_key=1234567890 --env log_collection=true --env service_name=service --env log_path=path docker.io/grafana/agent:main-amd64`

Example for setting environment variables using an env file:
`docker run --env-file env.list docker.io//grafana/agent:main-amd64`

For more information please visit the [docker documentation](https://docs.docker.com/engine/reference/commandline/run/#env)

### Options
Agent installation is enabled by default. To run without installing the agent, add " --install false" to the end of the run command. For example:  
sudo path/to/grafana-agent-autoconf.sh --install false

To modify a pre-existing config file, add " --config.file", followed by the path to the file, to the end of the run command. For example:  
sudo path/to/grafana-agent-autoconf.sh --config.file path/to/configfile  
A backup of your original file will be created.

You can use both --install and --config.file options in the same run command, order is irrelevant. For example:  
sudo path/to/grafana-agent-autoconf.sh --install false --config.file path/to/config
or
sudo path/to/grafana-agent-autoconf.sh --config.file path/to/config --install false

## Additional options
To add integrations without being prompted for credentials, there are several environment variables you can use:
- fr_api_key
- fr_mysql_user
- fr_mysql_password
- fr_mssql_user
- fr_mssql_password
- fr_postgres_user
- fr_postgres_password

The default connection strings used in the config file are:
- MySQL -`<username>:<password>@(127.0.0.1:3306)/`
- MSSQL -`sqlserver://<username>:<password>@1433:1433`
- Postgres -`postgresql://<username>:<password>@127.0.0.1:5432/shop?sslmode=disable`

To replace these with a custom connection string, there are several environment variables you can use:
- fr_mysql_connection_string
- fr_mssql_connection_string
- fr_postgres_connection_string

If there is a service running that you don't want to enable the integration for, you can use the relevant environment variable from the following options
to disable it by default when creating the configuration:
- fr_mysql_disabled
- fr_mssql_disabled
- fr_postgres_disabled

If you wish to use an environment file to set environment variables, rather than setting them as system environment variables,
you can do so by naming the file ".env" and placing it in the same directory as the "grafana-agent-autoconf" script.