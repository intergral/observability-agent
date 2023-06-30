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

## Static Mode Procedure
[Latest Release](https://github.com/intergral/observability-agent/releases) </br>

Static mode refers to the default, original variant of the Grafana Agent, which utilises yaml config files. </br>
For the Observability Agent, this refers to the `observability-agent-autoconf.sh` and `observability-agent-autoconf.ps1` scripts respectively.

To learn more about Static mode, visit [Grafana's Documentation](https://grafana.com/docs/agent/latest/static/).

### Linux-Static
To download and run the installer, in a terminal, run: </br>
```
curl -O -L "https://github.com/intergral/observability-agent/releases/download/v0.2.0/observability-agent-autoconf.sh"
chmod a+x "observability-agent-autoconf.sh"
sudo /bin/bash observability-agent-autoconf.sh
```

### Windows-Static
To download and run the installer, open powershell admin terminal, navigate to your desired download folder and run: </br>
```
Invoke-WebRequest -Uri "https://github.com/intergral/observability-agent/releases/download/v0.2.0/observability-agent-autoconf.ps1" -OutFile "observability-agent-autoconf.ps1"
.\observability-agent-autoconf.ps1
```

The installer for windows assumes you are installing the Grafana Agent in the default location on the C drive </br>
This is required for the config file to be placed in the correct location for the Grafana Agent to read it

## Flow Mode Procedure
[Latest Release](https://github.com/intergral/observability-agent/releases) </br>

Flow mode refers to a newer, re-imagined variant of the Grafana Agent, which utilises river config files. </br>
For the Observability Agent, this refers to the `observability-agent-flow-autoconf.sh` and `observability-agent-flow-autoconf.ps1` scripts respectively.

To learn more about Flow mode, visit [Grafana's Documentation](https://grafana.com/docs/agent/latest/flow/).

### Linux-Flow
To download and run the installer, in a terminal, run: </br>
```
curl -O -L "https://github.com/intergral/observability-agent/releases/download/v0.2.0/observability-agent-flow-autoconf.sh"
chmod a+x "observability-agent-flow-autoconf.sh"
sudo /bin/bash observability-agent-flow-autoconf.sh
```

### Windows-Flow
To download and run the installer, open powershell admin terminal, navigate to your desired download folder and run: </br>
```
Invoke-WebRequest -Uri "https://github.com/intergral/observability-agent/releases/download/v0.2.0/observability-agent-flow-autoconf.ps1" -OutFile "observability-agent-autoconf.ps1"
.\observability-agent-flow-autoconf.ps1
```

The installer for windows assumes you are installing the Grafana Agent Flow in the default location on the C drive </br>
This is required for the config file to be placed in the correct location for the Grafana Agent Flow to read it

## Options
> **All options apply to both [Static mode](#static-mode-procedure) and [Flow mode](#flow-mode-procedure) by replacing the relevant files in the examples.** </br>

Agent installation is enabled by default. To run without installing the agent, add `--install false` to the end of the run command. For example: </br>
`sudo path/to/observability-agent-autoconf.sh --install false`

To modify a pre-existing config file, add `--config.file`, followed by the path to the file, to the end of the run command. For example:
`sudo path/to/observability-agent-autoconf.sh --config.file path/to/configfile`  
A backup of your original file will be created

You can use both `--install` and `--config.file` options in the same run command, order is irrelevant. For example: </br>
`sudo path/to/observability-agent-autoconf.sh --install false --config.file path/to/config`</br>
or </br>
`sudo path/to/observability-agent-autoconf.sh --config.file path/to/config --install false`

## Docker
When running in Docker, you will not be prompted for any information. Therefore, you must specify an api key before running. Additionally, you must set the relevant
environment variables for whichever services you have running, so they can be configured. These environment variables can be found in the [Environment Variables](#environment-variables) section.

To run in docker, we provide prebuilt images. See our [Docker Hub](https://hub.docker.com/repository/docker/intergral/observability-agent/general) repository for more information

## Environment Variables
To add integrations without being prompted for credentials, there are several environment variables you can use:

### Ingest

| Variable           | Type     | Description                                                                                    |
|--------------------|----------|------------------------------------------------------------------------------------------------|
| `api_key`          | `string` | API Key to authenticate with your FusionReactor Cloud Account                                  |
| `metrics_Endpoint` | `string` | Default: `https://api.fusionreactor.io/v1/metrics`                                             |
| `logs_Endpoint`    | `string` | Default: `https://api.fusionreactor.io/v1/logs`                                                |
| `logs_user`        | `string` | Username to authenticate with your FusionReactor Cloud Account (observability-agent-flow only) |

### Metric Exporters

| Variable                 | Type     | Description                                                                      |
|--------------------------|----------|----------------------------------------------------------------------------------|
| `mysql_user`             | `string` | User for the local Mysql database                                                |
| `mysql_password`         | `string` | Password for the local Mysql database                                            |
| `mysql_disabled`         | `bool`   | Enables/Disables the Mysql exporter (enabled by default)                         |
| `mssql_user`             | `string` | User for the local Mssql database                                                |
| `mssql_password`         | `string` | Password for the local Mssql database                                            |
| `mssql_disabled`         | `bool`   | Enables/Disables the Mssql exporter (enabled by default)                         |
| `postgres_user`          | `string` | User for the local Postgres database                                             |
| `postgres_password`      | `string` | Password for the local Postgres database                                         |
| `postgres_disabled`      | `bool`   | Enables/Disables the Postgres exporter (enabled by default)                      |
| `rabbitmq_disabled`      | `bool`   | Enables/Disables the RabbitMQ exporter (enabled by default)                      |
| `redis_disabled`         | `bool`   | Enables/Disables the Redis exporter (enabled by default)                         |
| `elasticsearch_user`     | `string` | User for the Elastic search instance (observability-agent-flow incompatible)     |
| `elasticsearch_password` | `string` | Password for the Elastic search instance (observability-agent-flow incompatible) |

### Exporting metrics from external machines

To replace these with a custom connection string, there are several environment variables you can use:

| Variable                          | Type     | Example (Defaults)                                     |
|-----------------------------------|----------|--------------------------------------------------------|
| `mysql_connection_string`         | `string` | `<username>:<password>@(<host>:3306)/`                 |
| `mssql_connection_string`         | `string` | `sqlserver://<username>:<password>@<host>:1433`        |
| `postgres_connection_string`      | `string` | `postgresql://<username>:<password>@<host>:5432/shop?` |
| `rabbitmq_scrape_target`          | `string` | `<host>:15692`                                         |
| `redis_connection_string`         | `string` | `<host>:6379`                                          |
| `kafka_connection_string`         | `string` | `["<host>:9092"]`                                      |
| `elasticsearch_connection_string` | `string` | `http://<username>:<password>@<host>:9200`             |

RabbitMQ requires an internal exporter to be enabled. Visit [the documentation](https://www.rabbitmq.com/prometheus.html) for more information. <br>
`kafka_connection_string` and `elasticsearch_connection_string` are currently incompatible with observability-agent-flow.


### Log Exporters

If you wish to enable log collection, the following environment variables must be set:

| Variable           | Type     | Description                                     |
|--------------------|----------|-------------------------------------------------|
| `log_collection`   | `bool`   | Enables log collection                          |
| `service_name`     | `string` | Set a name for you log collection service       |
| `log_path`         | `string` | Set a file path for your log collection service |

### Scraping from additional exporters
At present, there are some integrations we don't support out the box. Use of these integrations is via a scrape endpoint.
To scrape these exporters, you can use the following environment variables to set a list of exporters and their corresponding endpoints to be scraped.
The list must be wrapped in double quotes and each value must be separated by a comma and a space.

| Variable         | Type     | Example                                  | Description                                                             |
|------------------|----------|------------------------------------------|-------------------------------------------------------------------------|
| `scrape_jobs`    | `string` | `"nginxexporter, iisexporter"`           | List of exporters to be scraped (observability-agent-flow incompatible) |
| `scrape_targets` | `string` | `"nginxexporter:9113, iisexporter:1234"` | List of endpoints for the exporters                                     |

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