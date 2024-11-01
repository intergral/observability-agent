## Introduction
The Observability Agent autoconfiguration and installer tool is a wrapper for [Grafana Alloy](https://github.com/grafana/alloy) that can install Alloy,
detect which services are running on your machine, and automatically create a configuration file with integrations for
detected services. A Node/Windows exporter integration will be added by default.

## Prerequisites
For Unix machines, the script will have to be run with root privileges, otherwise you will be prompted for your password during execution.
Windows machines must have Powershell 5.1 or later installed. macOS is not currently supported.

The script will automatically detect what's running on your machine and add integrations to the config file. For this, each service you want to have an integration
for must be running on its default port, these are:

| Integration         | Default Port |
|---------------------|--------------|
| `MySQL`             | `3306`       |
| `MSSQL`             | `1433`       |
| `Postgres`          | `5432`       |
| `RabbitMQ`          | `5672`       |
| `RabbitMQ Exporter` | `15692`      |
| `Redis`             | `6379`       |
| `Kafka`             | `9092`       |
| `Elasticsearch`     | `9200`       |
| `Mongo`             | `27017`      |
| `OracleDB`          | `1521`       |

## Procedure

> **Both the [Static Mode](https://grafana.com/docs/agent/latest/static/) installer and [Flow Mode](https://grafana.com/docs/agent/latest/flow/) installer have been deprecated and superseded by [Grafana Alloy](https://grafana.com/docs/alloy/latest/) installer** </br>

> **[Latest Release](https://github.com/intergral/observability-agent/releases)** </br>

### Linux
To download and run the installer, in a terminal, run: </br>
```
curl -O -L "https://github.com/intergral/observability-agent/releases/download/v0.2.3/observability-agent-autoconf.sh"
chmod a+x "observability-agent-autoconf.sh"
sudo /bin/bash observability-agent-autoconf.sh
```

### Windows
To download and run the installer, open powershell admin terminal, navigate to your desired download folder and run: </br>
```
Invoke-WebRequest -Uri "https://github.com/intergral/observability-agent/releases/download/v0.2.3/observability-agent-autoconf.ps1" -OutFile "observability-agent-autoconf.ps1"
.\observability-agent-autoconf.ps1
```

The installer for windows assumes you are installing Grafana Alloy in the default location on the C drive </br>
This is required for the config file to be placed in the correct location for the Grafana Alloy to read it

## Options

Grafana Alloy installation is enabled by default. To run without installing Alloy, add `--install false` to the end of the run command. For example: </br>
`sudo path/to/observability-agent-autoconf.sh --install false`

To modify a pre-existing config file, add `--config.file`, followed by the path to the file, to the end of the run command. For example:
`sudo path/to/observability-agent-autoconf.sh --config.file path/to/configfile`  
A backup of your original file will be created

To disable prompts that wait for user input, add `--prompt false` as command arguments.

You can use both `--install` and `--config.file` options in the same run command, order is irrelevant. For example: </br>
`sudo path/to/observability-agent-autoconf.sh --install false --config.file path/to/config`</br>
or </br>
`sudo path/to/observability-agent-autoconf.sh --config.file path/to/config --install false`

For Windows, you can add `--disable-dl-progress-bar true` to potentially speed up downloads.

## Docker
When running in Docker, you will not be prompted for any information. Therefore, you must specify an api key before running. Additionally, you must set the relevant
environment variables for whichever services you have running, so they can be configured. These environment variables can be found in the [Environment Variables](#environment-variables) section.

To run in docker, we provide prebuilt images. See our [Docker Hub](https://hub.docker.com/repository/docker/intergral/observability-agent/general) repository for more information

## Environment Variables
To add integrations without being prompted for credentials, there are several environment variables you can use:

### Ingest

| Variable           | Type     | Description                                                                          |
|--------------------|----------|--------------------------------------------------------------------------------------|
| `api_key`          | `string` | API Key to authenticate with your FusionReactor Cloud Account                        |
| `metrics_Endpoint` | `string` | Default: `https://api.fusionreactor.io/v1/metrics`                                   |
| `logs_Endpoint`    | `string` | Default: `https://api.fusionreactor.io/v1/logs`                                      |
| `log_level`        | `string` | Sets the log level. Valid values: "error", "warn", "info", "debug". Default: "warn"  | 

### Metric Exporters

| Variable                  | Type     | Description                                                          |
|---------------------------|----------|----------------------------------------------------------------------|
| `mysql_user`              | `string` | User for the local Mysql database                                    |
| `mysql_password`          | `string` | Password for the local Mysql database                                |
| `mysql_disabled`          | `bool`   | Enables/Disables the Mysql exporter (enabled by default)             |
| `mssql_user`              | `string` | User for the local Mssql database                                    |
| `mssql_password`          | `string` | Password for the local Mssql database                                |
| `mssql_disabled`          | `bool`   | Enables/Disables the Mssql exporter (enabled by default)             |
| `postgres_user`           | `string` | User for the local Postgres database                                 |
| `postgres_password`       | `string` | Password for the local Postgres database                             |
| `postgres_db`             | `string` | Database name for the local Postgres database (defaults to username) |
| `postgres_disabled`       | `bool`   | Enables/Disables the Postgres exporter (enabled by default)          |
| `rabbitmq_disabled`       | `bool`   | Enables/Disables the RabbitMQ exporter (enabled by default)          |
| `rabbitmq_instance_label` | `string` | Optional variable to set the RabbitMQ instance identifier            |
| `redis_disabled`          | `bool`   | Enables/Disables the Redis exporter (enabled by default)             |
| `elasticsearch_user`      | `string` | User for the Elastic search instance                                 |
| `elasticsearch_password`  | `string` | Password for the Elastic search instance                             |
| `elasticsearch_disabled`  | `bool`   | Enables/Disables the Elastic search exporter (enabled by default)    |
| `mongodb_user`            | `string` | User for the local Mongo database                                    |
| `mongodb_password`        | `string` | Password for the local Mongo database                                |
| `mongodb_disabled`        | `bool`   | Enables/Disables the MongoDB exporter (enabled by default)           |
| `oracledb_user`           | `string` | User for the local Oracle database                                   |
| `oracledb_password`       | `string` | Password for the local Oracle database                               |
| `oracledb_disabled`       | `bool`   | Enables/Disables the OracleDB exporter (enabled by default)          |

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
| `mongodb_connection_string`       | `string` | `mongodb://<username>:<password>@<host>:27017/`        |
| `oracledb_connection_string`      | `string` | `oracle://<username>:<password>@<host>:1521/ORCLCDB`   |

RabbitMQ requires an internal exporter to be enabled. Visit [the documentation](https://www.rabbitmq.com/prometheus.html) for more information. <br>

### Log Exporters

If you wish to enable log collection, the following environment variables must be set:

| Variable           | Type     | Example         | Description                                     |
|--------------------|----------|-----------------|-------------------------------------------------|
| `log_collection`   | `bool`   | `true`          | Enables log collection                          |
| `service_name`     | `string` | `service`       | Set a name for you log collection service       |
| `log_path`         | `string` | `/service/logs` | Set a file path for your log collection service |

### Open Telemetry

If you wish to enable Open Telemetry metrics and traces, the following environment variables must be set:

| Variable          | Type     | Example | Description                                     |
|-------------------|----------|---------|-------------------------------------------------|
| `otel_collection` | `bool`   | `true`  | Enables Open Telemetry metrics, traces and logs |

### Scraping from additional exporters
At present, there are some integrations we don't support out the box. Use of these integrations is via a scrape endpoint.
To scrape these exporters, you can use the following environment variables to set a list of exporters and their corresponding endpoints to be scraped.
The list must be wrapped in double quotes and each value must be separated by a comma and a space.

| Variable         | Type     | Example                                  | Description                                                             |
|------------------|----------|------------------------------------------|-------------------------------------------------------------------------|
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