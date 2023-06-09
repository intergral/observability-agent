# Flags
while ($args) {
    switch ($args[0]) {
        "--config.file" {
            $CONFIG = $args[1]
            $args = $args[2..$args.Count]
            break
        }
        "--install" {
            switch ($args[1]) {
                "true" {
                    $INSTALL = $true
                    break
                }
                "false" {
                    $INSTALL = $false
                    break
                }
                default {
                    Write-Error "Invalid value for --install flag: $($args[1])"
                    exit 1
                }
            }
            $args = $args[2..$args.Count]
            break
        }
        default {
            Write-Error "Invalid option: $($args[0])"
            exit 1
        }
    }
}

if ($INSTALL -ne $false) {

    $uri = "https://api.github.com/repos/grafana/agent/releases/latest"
    $release = Invoke-RestMethod -Uri $uri

    # Extract the download URL for the Windows installer from the release assets
    $url = ($release.assets | Where-Object { $_.name -like "grafana-agent-flow-installer.exe.zip" }).browser_download_url

    $outputPath = "$PSScriptRoot/grafana-agent-flow-installer.exe.zip"
    $installPath = "$PSScriptRoot/grafana-agent-flow-installer.exe"

    # Download the file
    Invoke-WebRequest -Uri $url -OutFile $outputPath

    # Extract the contents of the zip file
    Expand-Archive -Path $outputPath -DestinationPath $installPath -Force

    # Run the installer
    Start-Process "$installPath\grafana-agent-flow-installer.exe"
}

#Check if an env file exists
if (Test-Path ".env") {
    # Adds each variable to the $env automatic variable
    foreach ($line in Get-Content ".env") {
        if ($line -match '^([^=]+)=(.*)$') {
            Set-Item -Path "env:$($matches[1])" -Value $matches[2]
        }
    }
}

# Check if the configuration file exists and is valid
if (($CONFIG) -and (Test-Path $CONFIG -PathType Leaf)) {
    Write-Output "Config file found"
    # Backup config
    Copy-Item -Path "$CONFIG" -Destination "$CONFIG.bak" -Force -PassThru | Out-Null
} else {
    Write-Output "No pre-existing config file found"
    $CONFIG="grafana-agent-flow.river"
    Write-Output "Creating configuration file: $CONFIG"
}

# Get API key
if ($env:api_key) {
    Write-Host "API key found"
    $key = $env:api_key
}
else {
    # Prompt for API key
    Write-Host "API key not found"
    $key = Read-Host "Enter your API key"
}

if ($env:metrics_endpoint)
{
    $metricsEndpoint = $env:metrics_endpoint
}
else
{
    $metricsEndpoint = "https://api.fusionreactor.io/v1/metrics"
}

# Create config file
# Enable prometheus remote write component and logging component
@"
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

"@ | Out-File -FilePath $CONFIG
Write-Output "Prometheus remote write component enabled"

# Enable windows exporter component
@"
prometheus.exporter.windows "example" {

}

prometheus.scrape "windows" {
	targets    = prometheus.exporter.windows.example.targets
	forward_to = [prometheus.remote_write.default.receiver]
}

"@ | Out-File -FilePath $CONFIG -Append
Write-Output "Windows exporter component enabled"

while ($true) {
    if (-not $env:log_collection)
    {
        $ans = Read-Host "Is there a service you want to enable log collection for? (y/n)" | ForEach-Object { $_.ToLower() }
    }
    elseif ($env:log_collection = $true) {
        $ans="y"
    }
    else
    {
        $ans="n"
    }

    if ($ans -eq "y") {
        if ($env:service_name)
        {
            $job = $env:service_name
        }
        else
        {
            $job = Read-Host "Enter the service name"
        }

        if ($env:log_path)
        {
            $path = $env:log_path
        }
        else
        {
            $path = Read-Host "Enter the path to the log file"
        }

        if ($env:logs_endpoint)
        {
            $logsEndpoint=$env:logs_endpoint
        }
        else
        {
            $logsEndpoint="https://api.fusionreactor.io/v1/logs"
        }

        if ($env:log_user)
        {
            $logUser=$env:log_user
        }
        else
        {
            $logUser = Read-Host "Enter your endpoint user"
        }

        # Add log collection
        @"
discovery.file "varlog" {
  path_targets = [
    {__path__ = "$path", job = "$job"},
  ]
}

loki.source.file "httpd" {
  targets    = discovery.file.varlog.targets
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

"@ | Out-File -FilePath $CONFIG -Append
        break
    } elseif ($ans -eq "n") {
        break
    } else {
        Write-Output "Invalid input. Please enter y or n."
    }
}

#Detect MySQL
if ((Get-NetTCPConnection).LocalPort -contains 3306 -or $env:mysql_connection_string){
    Write-Host "MySQL detected"
    # Check if connection string already set in environment
    if (-not $env:mysql_connection_string)
    {
        # Check if credentials already set in environment
        if (-not $env:mysql_user -or -not $env:mysql_password)
        {
            Write-Host "MySQL credentials not found"

            while ($true)
            {
                Write-Host "Enter your username:"
                $user = Read-Host
                if ( [string]::IsNullOrWhiteSpace($user))
                {
                    Write-Host "Username cannot be empty. Please enter a valid username."
                }
                else
                {
                    break
                }
            }

            while ($true)
            {
                Write-Host "Enter your password:"
                $pass = Read-Host -AsSecureString
                $passText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
                if ( [string]::IsNullOrWhiteSpace($passText))
                {
                    Write-Host "Password cannot be empty. Please enter a valid password."
                }
                else
                {
                    break
                }
            }

            $myDatasource = "${user}:${passText}@(127.0.0.1:3306)/"

        }
        else
        {
            Write-Output "MySQL credentials found"
            $myDatasource = "${env:mysql_user}:${env:mysql_password}@(127.0.0.1:3306)/"
        }
    } else {
        $myDatasource = $env:mysql_connection_string
    }

    # Add integration
    if ($env:mysql_disabled -eq $true) {
        Write-Output "MySQL integration configured"
    } else {
        @"
prometheus.exporter.mysql "example" {
  data_source_name = "$myDatasource"
}

prometheus.scrape "mysql" {
  targets    = prometheus.exporter.mysql.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

"@ | Out-File -FilePath $CONFIG -Append
        Write-Output "MySQL integration enabled"
    }
}

#Detect MSSQL
if ((Get-NetTCPConnection).LocalPort -contains 1433 -or $env:mssql_connection_string){
    Write-Host "MSSQL detected"
    # Check if connection string already set in environment
    if (-not $env:mssql_connection_string)
    {
        # Check if credentials already set in environment
        if (-not $env:mssql_user -or -not $env:mssql_password)
        {
            Write-Host "MSSQL credentials not found"
            while ($true)
            {
                Write-Host "Enter your username:"
                $user = Read-Host
                if ( [string]::IsNullOrWhiteSpace($user))
                {
                    Write-Host "Username cannot be empty. Please enter a valid username."
                }
                else
                {
                    break
                }
            }

            while ($true)
            {
                Write-Host "Enter your password:"
                $pass = Read-Host -AsSecureString
                $passText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
                if ( [string]::IsNullOrWhiteSpace($passText))
                {
                    Write-Host "Password cannot be empty. Please enter a valid password."
                }
                else
                {
                    break
                }
            }

            $msDatasource = "sqlserver://${user}:${passText}@1433:1433"

        }
        else
        {
            Write-Output "MSSQL credentials found"
            $msDatasource = "sqlserver://${env:mssql_user}:${env:mssql_password}@1433:1433"
        }
    } else {
        $msDatasource = $env:mssql_connection_string
    }
    # Add integration
    if ($env:mssql_disabled -eq $true) {
        Write-Output "MSSQL integration configured"
    } else {
        @"
prometheus.exporter.mssql "example" {
  connection_string = "$msDatasource"
}

prometheus.scrape "mssql" {
  targets    = prometheus.exporter.mssql.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

"@ | Out-File -FilePath $CONFIG -Append
        Write-Output "MSSQL integration enabled"
    }
}

#Detect Postgres
if ((Get-NetTCPConnection).LocalPort -contains 5432 -or $env:postgres_connection_string){
    Write-Host "Postgres detected"
    # Check if connection string already set in environment
    if (-not $env:postgres_connection_string)
    {
        # Check if credentials already set in environment
        if (-not $env:postgres_user -or -not $env:postgres_password)
        {
            Write-Host "Postgres credentials not found"
            while ($true)
            {
                Write-Host "Enter your username:"
                $user = Read-Host
                if ( [string]::IsNullOrWhiteSpace($user))
                {
                    Write-Host "Username cannot be empty. Please enter a valid username."
                }
                else
                {
                    break
                }
            }

            while ($true)
            {
                Write-Host "Enter your password:"
                $pass = Read-Host -AsSecureString
                $passText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
                if ( [string]::IsNullOrWhiteSpace($passText))
                {
                    Write-Host "Password cannot be empty. Please enter a valid password."
                }
                else
                {
                    break
                }
            }

            $postgresDatasource = "postgresql://${user}:${passText}@127.0.0.1:5432/postgres?sslmode=disable"

        }
        else
        {
            Write-Output "Postgres credentials found"
            $postgresDatasource = "postgresql://${env:postgres_user}:${env:postgres_password}@127.0.0.1:5432/postgres?sslmode=disable"
        }
    } else {
        $postgresDatasource = $env:postgres_connection_string
    }

    # Add integration
    if ($env:postgres_disabled -eq $true) {
        Write-Output "Postgres integration configured"
    }

    else {
        @"
prometheus.exporter.postgres "example" {
    data_source_names = ["$postgresDatasource"]
    autodiscovery {
        enabled = true
    }
}

prometheus.scrape "postgres" {
  targets    = prometheus.exporter.postgres.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

"@ | Out-File -FilePath $CONFIG -Append
        Write-Output "Postgres integration enabled"
    }
}

#Detect RabbitMQ
if ((Get-NetTCPConnection).LocalPort -contains 5672 -or $env:rabbitmq_scrape_target)
{
    Write-Output "RabbitMQ detected"
    if (!($env:rabbitmq_disabled -eq $true))
    {
        if (!(Get-NetTCPConnection).LocalPort -contains 15692)
        {
            Write-Output "RabbitMQ exporter is not enabled, see the Observability Agent docs to learn how to enable it"
        }
        if ($env:rabbitmq_scrape_target)
        {
            # Add the endpoint to the config
            @"
prometheus.scrape "rabbit" {
  targets = [
    {"__address__" = "$rabbitmq_scrape_target", "instance" = "one"},
  ]

  forward_to = [prometheus.remote_write.default.receiver]
}

"@ | Out-File -FilePath $CONFIG -Append
        }
        else
        {
            # Add the endpoint to the config
            @"
prometheus.scrape "rabbit" {
  targets = [
    {"__address__" = "127.0.0.1:15692", "instance" = "one"},
  ]

  forward_to = [prometheus.remote_write.default.receiver]
}

"@ | Out-File -FilePath $CONFIG -Append
            Write-Output "RabbitMQ scrape endpoint added"
        }
    }
}

# Detect Redis
if ((Get-NetTCPConnection).LocalPort -contains 6379 -or $env:redis_connection_string){
    Write-Host "Redis detected"
    # Check if connection string already set in environment
    if (-not $env:redis_connection_string)
    {
        $redisDatasource = "127.0.0.1:6379"
    } else {
        $redisDatasource = $env:redis_connection_string
    }

    # Add integration
    if ($env:redis_disabled -eq $true) {
        Write-Output "Redis integration configured"
    } else {
        @"
prometheus.exporter.redis "example" {
  redis_addr = "$redisDatasource"
}

prometheus.scrape "redis" {
  targets    = prometheus.exporter.redis.example.targets
  forward_to = [prometheus.remote_write.default.receiver]
}

"@ | Out-File -FilePath $CONFIG -Append
        Write-Output "Redis integration enabled"
    }
}

if ($env:scrape_targets) {
    # Split the variables into arrays
    $scrapeTargets = $env:scrape_targets.Trim('"') -split ", "
    @"
prometheus.scrape "endpoints" {
  targets = [
"@ | Out-File -FilePath $CONFIG -Append

    # Add the jobs and targets to the config
    for ($i=0; $i -lt $scrapeTargets.Length; $i++) {
        # Add the endpoint to the config
        @"
    {"__address__" = "${scrapeTargets[i]}"},
"@ | Out-File -FilePath $CONFIG -Append
    }
    @"
  ]
  forward_to = [prometheus.remote_write.default.receiver]
}

"@ | Out-File -FilePath $CONFIG -Append
    Write-Host "Scrape endpoints added"
}

while ($true)
{
    @"
prometheus.scrape "endpoints" {
  targets = [
"@ | Out-File -FilePath $CONFIG -Append

    $ans = Read-Host "Is there an additional endpoint you would like to scrape? (y/n)" | ForEach-Object { $_.ToLower() }
    if ($ans -eq "y") {
        $endpointName = Read-Host "Enter the name of the service being scraped"
        $endpointTarget = Read-Host "Enter the target to be scraped"
        if ([string]::IsNullOrWhiteSpace($endpointName) -or [string]::IsNullOrWhiteSpace($endpointTarget))
        {
            Write-Host "Fields cannot be empty"
        }
        else
        {
            # Add the endpoint to the config
            @"
    {"__address__" = "$endpointTarget"},
"@ | Out-File -FilePath $CONFIG -Append
        }
    } elseif ($ans -eq "n") {
        @"
  ]
  forward_to = [prometheus.remote_write.default.receiver]
}

"@ | Out-File -FilePath $CONFIG -Append
        break
    } else {
        Write-Output "Invalid input. Please enter y or n."
    }
    @"
  ]
  forward_to = [prometheus.remote_write.default.receiver]
}

"@ | Out-File -FilePath $CONFIG -Append
    break
}
Write-Output "Config file updated"

Move-Item -Path $CONFIG -Destination "C:\Program Files\Grafana Agent Flow\config.river" -Force
Write-Host "Config file can be found at C:\Program Files\Grafana Agent Flow\config.river"
Restart-Service -Name "Grafana Agent Flow" -Force