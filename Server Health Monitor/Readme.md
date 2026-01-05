\# Server Health Monitoring \& Auto-Remediation (PowerShell)



An enterprise-grade PowerShell automation solution designed to monitor Windows server health, perform self-healing actions, and send real-time alerts to administrators.



This project reflects real-world production monitoring used in large enterprise environments.



---



\## Features



\- CPU, Memory, and Disk utilization monitoring  

\- Critical service monitoring with auto-restart  

\- DFS Replication service health check  

\- File Share availability validation  

\- Printer health monitoring  

\- Centralized activity and error logging  

\- Email and Microsoft Teams alerting  

\- Externalized configuration using JSON  

\- Safe execution with isolated error handling  



---



\## Health Checks Explained



\### CPU Monitoring

\- Uses CIM (Win32\_Processor)

\- Calculates average CPU utilization

\- Triggers alerts when configured threshold is exceeded



---



\### Memory Monitoring

\- Calculates used memory percentage

\- Helps prevent memory exhaustion-related outages



---



\### Disk Monitoring

\- Scans all local disks

\- Detects drives approaching full capacity



---



\### Service Monitoring \& Auto-Restart

\- Monitors critical business services

\- Automatically restarts stopped services

\- Logs both failure and recovery actions



---



\### DFS Replication Check

\- Ensures DFS Replication service is running

\- Automatically restarts service if stopped

\- No dependency on external utilities



---



\### File Share Validation

\- Verifies SMB service availability

\- Detects file share access issues



---



\### Printer Monitoring

\- Scans all printers on the server

\- Detects printers in abnormal states

\- Logs affected printer names



---



\## Logging Strategy



\### health.log

\- Successful health checks

\- Auto-remediation actions

\- Script execution status



\### error.log

\- Timestamp  

\- Component name  

\- Exception message and type  

\- Script name and line number  

\- Full stack trace  



This logging design enables faster root cause analysis in production environments.



---



\## Alerting Mechanism



\### Email Alerts

\- Secure SMTP authentication

\- Consolidated alert summary

\- Hostname included in the email subject



\### Microsoft Teams Alerts

\- Real-time notifications via webhook

\- Single message containing all detected issues



---



\## Error Handling Philosophy



\- Every component runs inside Try/Catch

\- Failure in one health check does not stop script execution

\- Safe for scheduled and unattended execution



---



\## Configuration (config.json)



Open the config.json file in any editor to:



\- Add or remove monitored services

\- Adjust CPU, Memory, and Disk threshold levels

\- Configure SMTP email settings

\- Configure Microsoft Teams webhook URL



---



\## How to Run



```powershell

Set-ExecutionPolicy RemoteSigned -Scope Process

.\\health-monitor.ps1



