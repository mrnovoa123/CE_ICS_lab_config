# provision/win10.ps1 — Sysmon + agente Wazuh
param([string]$AgentVer = "4.14.0-1")
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = "C:\lab"; New-Item -ItemType Directory -Force $tmp | Out-Null

# --- 1. Permitir ping desde la LAN del laboratorio ---
if (-not (Get-NetFirewallRule -DisplayName "LAB ICMPv4 entrada" -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName "LAB ICMPv4 entrada" -Protocol ICMPv4 -IcmpType 8 `
    -Direction Inbound -Action Allow -RemoteAddress 10.10.10.0/24 | Out-Null
}

# --- 2. Sysmon con la configuración de SwiftOnSecurity ---
Invoke-WebRequest https://download.sysinternals.com/files/Sysmon.zip -OutFile "$tmp\Sysmon.zip" -UseBasicParsing
Expand-Archive "$tmp\Sysmon.zip" -DestinationPath "$tmp\Sysmon" -Force
Invoke-WebRequest https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml -OutFile "$tmp\sysmonconfig.xml" -UseBasicParsing
& "$tmp\Sysmon\Sysmon64.exe" -accepteula -i "$tmp\sysmonconfig.xml"

# --- 3. Agente Wazuh ---
Invoke-WebRequest "https://packages.wazuh.com/4.x/windows/wazuh-agent-$AgentVer.msi" -OutFile "$tmp\wazuh-agent.msi" -UseBasicParsing
Start-Process msiexec.exe -Wait -ArgumentList "/i $tmp\wazuh-agent.msi /q WAZUH_MANAGER=10.10.10.10 WAZUH_AGENT_NAME=win10"

# Eventos de Sysmon hacia Wazuh
$conf = "C:\Program Files (x86)\ossec-agent\ossec.conf"
if (-not (Select-String -Path $conf -Pattern "Sysmon/Operational" -Quiet)) {
  Add-Content $conf @"

<ossec_config>
  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
</ossec_config>
"@
}
Restart-Service WazuhSvc -ErrorAction SilentlyContinue
if ((Get-Service WazuhSvc).Status -ne "Running") { Start-Service WazuhSvc }
Write-Host "win10 lista"
