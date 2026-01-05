# =====================================================
# SERVER HEALTH MONITORING SCRIPT (ENTERPRISE GRADE)
# =====================================================

# -------- CONFIG LOAD --------
$alerts = @()

$BasePath = $PSScriptRoot

$configPath = Join-Path $BasePath "config.json"
$logsPath   = Join-Path $BasePath "logs"
$ActivityLog = Join-Path $logsPath "health.log"
$ErrorLog    = Join-Path $logsPath "error.log"

$config = Get-Content $configPath | ConvertFrom-Json

# -------- FILE CREATIONS --------

if (-not (Test-Path $logsPath)) {
    New-Item -ItemType Directory -Path $logsPath | Out-Null
}


if (-not (Test-Path $ActivityLog)) {
    New-Item -ItemType File -Path $ActivityLog | Out-Null
}

if (-not (Test-Path $ErrorLog)) {
    New-Item -ItemType File -Path $ErrorLog | Out-Null
}


# -------- LOGGING FUNCTIONS --------

Function Write-ActivityLog {
    param([string]$Message)
    Add-Content -Path $ActivityLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | INFO | $Message"
}

Function Write-ErrorLog {
    param(
        [string]$Component,
        [System.Exception]$Exception
    )

    $errorMessage = @"
=================================================
TIME      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
COMPONENT : $Component
MESSAGE   : $($Exception.Message)
TYPE      : $($Exception.GetType().FullName)
SCRIPT    : $($Exception.InvocationInfo.ScriptName)
LINE      : $($Exception.InvocationInfo.ScriptLineNumber)
COMMAND   : $($Exception.InvocationInfo.Line)
STACKTRACE:
$($Exception.StackTrace)
=================================================

"@
    Add-Content -Path $ErrorLog -Value $errorMessage
}

# =====================================================
# CPU CHECK
# =====================================================
Try {
    $cpu = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
    if ($cpu -gt $config.CpuThreshold) {
        $alerts += "High CPU usage: $cpu%"
        Write-ActivityLog "CPU usage exceeded threshold: $cpu%"
    }
}
Catch {
    Write-ErrorLog -Component "CPU Check" -Exception $_.Exception
}

# =====================================================
# MEMORY CHECK
# =====================================================
Try {
    $os = Get-CimInstance Win32_OperatingSystem
    $memUsed = (($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100
    $memUsed = [math]::Round($memUsed, 2)

    if ($memUsed -gt $config.MemoryThreshold) {
        $alerts += "High Memory usage: $memUsed%"
        Write-ActivityLog "Memory usage exceeded threshold: $memUsed%"
    }
}
Catch {
    Write-ErrorLog -Component "Memory Check" -Exception $_.Exception
}

# =====================================================
# DISK CHECK
# =====================================================
Try {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $used = 100 - (($_.FreeSpace / $_.Size) * 100)
        $used = [int]$used
        if ($used -gt $config.DiskThreshold) {
            $alerts += "Disk $($_.DeviceID) usage high: $used%"
            Write-ActivityLog "Disk $($_.DeviceID) usage high: $used%"
        }
    }
}
Catch {
    Write-ErrorLog -Component "Disk Check" -Exception $_.Exception
}

# =====================================================
# SERVICE MONITOR + AUTO-RESTART
# =====================================================
foreach ($service in $config.CriticalServices) {
    Try {
        $svc = Get-Service -Name $service -ErrorAction Stop

        if ($svc.Status -ne "Running") {

            if ($svc.StartType -eq 'Disabled') {
                Set-Service -Name $service -StartupType Automatic
                Write-ActivityLog "Service $service startup type changed to Automatic."
            }

            Start-Service -Name $service -ErrorAction Stop
            $alerts += "Service $service was down and restarted."
            Write-ActivityLog "Service $service restarted successfully."
        }
    }
    Catch {
        $alerts += "Service $service could not be restarted."
        Write-ErrorLog -Component "Service Monitor - $service" -Exception $_.Exception
    }
}


# =====================================================
# DFS SERVICE CHECK (NO dfsutil DEPENDENCY)
# =====================================================
Try {
    $dfs = Get-Service DFSR -ErrorAction Stop
    if ($dfs.Status -ne "Running") {
        Start-Service DFSR -ErrorAction Stop
        $alerts += "DFSR service was down and restarted."
        Write-ActivityLog "DFSR service restarted."
    }
}
Catch {
    Write-ErrorLog -Component "DFS Replication Check" -Exception $_.Exception
}

# =====================================================
# FILE SHARE CHECK
# =====================================================
Try {
    Get-SmbShare -ErrorAction Stop | Out-Null
}
Catch {
    $alerts += "File Share service issue detected."
    Write-ErrorLog -Component "File Share Check" -Exception $_.Exception
}

# =====================================================
# PRINTER CHECK
# =====================================================
Try {
    Get-Printer -ErrorAction Stop | Where-Object { $_.PrinterStatus -ne "Normal" } | ForEach-Object {
        $alerts += "Printer issue detected: $($_.Name)"
        Write-ActivityLog "Printer issue detected: $($_.Name)"
    }
}
Catch {
    Write-ErrorLog -Component "Printer Check" -Exception $_.Exception
}

# =====================================================
# ALERTING (EMAIL + TEAMS)
# =====================================================
if ($alerts.Count -gt 0) {

    $alertBody = $alerts -join "`n"
    Write-ActivityLog "Alerts triggered."

    # ----- EMAIL ALERT -----
    Try {
        $securePass = ConvertTo-SecureString $config.Smtp.Password -AsPlainText -Force
        $cred = New-Object PSCredential ($config.Smtp.Username, $securePass)

        Send-MailMessage `
            -From $config.Smtp.From `
            -To $config.Smtp.To `
            -Subject "🚨 Server Health Alert - $(hostname)" `
            -Body $alertBody `
            -SmtpServer $config.Smtp.Server `
            -Port $config.Smtp.Port `
            -UseSsl `
            -Credential $cred
    }
    Catch {
        Write-ErrorLog -Component "Email Alert" -Exception $_.Exception
    }

    # ----- TEAMS ALERT -----
    Try {
        $teamsPayload = @{
            text = "🚨 **Server Health Alert** `n`n$alertBody"
        } | ConvertTo-Json

        Invoke-RestMethod `
            -Uri $config.TeamsWebhookUrl `
            -Method Post `
            -Body $teamsPayload `
            -ContentType "application/json"
    }
    Catch {
        Write-ErrorLog -Component "Teams Alert" -Exception $_.Exception
    }
}

# =====================================================
Write-ActivityLog "Health monitoring cycle completed."
# =====================================================
