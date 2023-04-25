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
    $url = ($release.assets | Where-Object { $_.name -like "grafana-agent-installer.exe.zip" }).browser_download_url

    $outputPath = "$PSScriptRoot/grafana-agent-installer.exe.zip"
    $installPath = "$PSScriptRoot/grafana-agent-installer.exe"

    # Download the file
    Invoke-WebRequest -Uri $url -OutFile $outputPath

    # Extract the contents of the zip file
    Expand-Archive -Path $outputPath -DestinationPath $installPath -Force

    # Run the installer
    Start-Process "$installPath\grafana-agent-installer.exe"
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
    $CONFIG="grafana-agent.yaml"
    Write-Output "Creating configuration file: $CONFIG"
}

# Get API key
if (-not $env:fr_api_key) {
    # Prompt for API key
    Write-Host "API key not found"
    $key = Read-Host "Enter your API key"
}
else {
    Write-Host "API key found"
    $key = $env:fr_api_key
}

# Create config file
@"
server:
  log_level: warn
metrics:
  global:
    scrape_interval: 1m
    remote_write:
      - url: https://api.fusionreactor.io/v1/metrics
        authorization:
          credentials: '$key'
integrations:
  agent:
    enabled: true
  windows_exporter:
    enabled: true
"@ | Out-File -FilePath $CONFIG

# Install and import the powershell-yaml module
Write-Output "Installing powershell-yaml module..."
Install-Module powershell-yaml -Scope CurrentUser
Import-Module powershell-yaml

while ($true) {
    $ans = Read-Host "Is there a service you want to enable log collection for? (y/n)" | ForEach-Object { $_.ToLower() }
    if ($ans -eq "y") {
        $path = Read-Host "Enter the service name"
        $job = Read-Host "Enter the path to the log file"

        # Add log collection
        $logContent = @"
logs:
  configs:
    - name: default
      positions:
        filename: /tmp/positions.yaml
      clients:
        - url: https://api.fusionreactor.io/v1/logs
          authorization:
            credentials: '$key'
      scrape_configs:
        - job_name: '$job'
          static_configs:
            - targets:
                - localhost
              labels:
                job: '$job'
                host: localhost
                __path__: '$path'
"@
        $logContent | Out-File -FilePath $CONFIG -Append
        Write-Output "Logs done"
        break
    } elseif ($ans -eq "n") {
        break
    } else {
        Write-Output "Invalid input. Please enter y or n."
    }
}

# Load config file
$configContent = Get-Content -Path $CONFIG -Raw | ConvertFrom-Yaml

# This also clears existing integrations but they need to be there for this to work
$integrationProperties = [System.Collections.Specialized.OrderedDictionary]::new()
$configContent.integrations = $integrationProperties

# Enable Agent
$integrationProperties.Add('agent', @{
    enabled = $true
})
# Enable Windows exporter
$integrationProperties.Add('windows_exporter', @{
    enabled = $true
})
Write-Output "Windows exporter integration enabled"

#Detect MySQL
if ((Get-NetTCPConnection).LocalPort -contains 3306){
    Write-Host "MySQL detected"
    # Check if connection string already set in environment
    if (-not $env:fr_mysql_connection_string)
    {
        # Check if credentials already set in environment
        if (-not $env:fr_mysql_user -or -not $env:fr_mysql_password)
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
            $myDatasource = "${env:fr_mysql_user}:${env:fr_mysql_password}@(127.0.0.1:3306)/"
        }
    } else {
        $myDatasource = $env:fr_mysql_connection_string
    }

    # Add integration
    if ($env:fr_mysql_disabled -eq $true) {
        $integrationProperties.Add('mysqld_exporter', [ordered]@{
            enabled = $false
            data_source_name = $myDatasource
        })
        Write-Output "MySQL integration configured"
    } else {
        $integrationProperties.Add('mysqld_exporter', [ordered]@{
            enabled = $true
            data_source_name = $myDatasource
        })
        Write-Output "MySQL integration enabled"
    }
}

#Detect MSSQL
if ((Get-NetTCPConnection).LocalPort -contains 1433) {
    Write-Host "MSSQL detected"
    # Check if connection string already set in environment
    if (-not $env:fr_mssql_connection_string)
    {
        # Check if credentials already set in environment
        if (-not $env:fr_mssql_user -or -not $env:fr_mssql_password)
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
            $msDatasource = "sqlserver://${env:fr_mssql_user}:${env:fr_mssql_password}@1433:1433"
        }
    } else {
        $msDatasource = $env:fr_mssql_connection_string
    }
    # Add integration
    if ($env:fr_mssql_disabled -eq $true) {
        $integrationProperties.Add('mssql', [ordered]@{
            enabled = $false
            connection_string = $msDatasource
        })
        Write-Output "MSSQL integration configured"
    } else {
        $integrationProperties.Add('mssql', [ordered]@{
            enabled = $true
            connection_string = $msDatasource
        })
        Write-Output "MSSQL integration enabled"
    }
}

#Detect Postgres
if ((Get-NetTCPConnection).LocalPort -contains 5432) {
    Write-Host "Postgres detected"
    # Check if connection string already set in environment
    if (-not $env:fr_postgres_connection_string)
    {
        # Check if credentials already set in environment
        if (-not $env:fr_postgres_user -or -not $env:fr_postgres_password)
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

            $postgresDatasource = "postgresql://${user}:${passText}@127.0.0.1:5432/shop?sslmode=disable"

        }
        else
        {
            Write-Output "Postgres credentials found"
            $postgresDatasource = "postgresql://${env:fr_postgres_user}:${env:fr_postgres_password}@127.0.0.1:5432/shop?sslmode=disable"
        }
    } else {
        $postgresDatasource = $env:fr_postgres_connection_string
    }
    # Add integration
    if ($env:fr_postgres_disabled -eq $true) {
        $integrationProperties.Add('postgres_exporter', [ordered]@{
            enabled = $false
            connection_string = $postgresDatasource
        })
        Write-Output "Postgres integration configured"
    } else {
        $integrationProperties.Add('postgres_exporter', [ordered]@{
            enabled = $true
            connection_string = $postgresDatasource
        })
        Write-Output "Postgres integration enabled"
    }
}

$configContent | ConvertTo-Yaml | Set-Content -Path $CONFIG
Write-Output "Config file updated"