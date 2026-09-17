#!/usr/bin/env bash
# provision/srvweb.sh — LAMP + DVWA + usuario débil SSH + agente Wazuh
set -euo pipefail
AGENT_VER="${1:-4.14.0-1}"
export DEBIAN_FRONTEND=noninteractive

# --- 1. Pila LAMP ---
apt-get update
apt-get install -y apache2 mariadb-server php php-mysqli php-gd libapache2-mod-php git curl gnupg

# --- 2. DVWA (instalada en Apache, no en contenedor) ---
[ -d /var/www/html/dvwa ] || git clone --depth 1 https://github.com/digininja/DVWA.git /var/www/html/dvwa
cp /var/www/html/dvwa/config/config.inc.php.dist /var/www/html/dvwa/config/config.inc.php
mysql -e "CREATE DATABASE IF NOT EXISTS dvwa;
  CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'p@ssw0rd';
  GRANT ALL ON dvwa.* TO 'dvwa'@'localhost'; FLUSH PRIVILEGES;"
sed -i 's/^allow_url_include = .*/allow_url_include = On/' /etc/php/*/apache2/php.ini
chown -R www-data:www-data /var/www/html/dvwa
systemctl restart apache2

# --- 3. Usuario con contraseña débil para la fuerza bruta SSH ---
id empleado &>/dev/null || useradd -m -s /bin/bash empleado
echo 'empleado:123456' | chpasswd
echo 'PasswordAuthentication yes' > /etc/ssh/sshd_config.d/00-lab.conf
systemctl restart ssh

# --- 4. Agente Wazuh (misma versión o menor que el manager) ---
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
apt-get update
WAZUH_MANAGER="10.10.10.10" WAZUH_AGENT_NAME="srvweb" apt-get install -y "wazuh-agent=${AGENT_VER}"
apt-mark hold wazuh-agent

# Logs de Apache hacia Wazuh
grep -q apache2/access.log /var/ossec/etc/ossec.conf || cat >> /var/ossec/etc/ossec.conf <<'EOF'

<ossec_config>
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/access.log</location>
  </localfile>
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/error.log</location>
  </localfile>
</ossec_config>
EOF
systemctl daemon-reload
systemctl enable --now wazuh-agent
echo "srvweb listo: http://192.168.56.30/dvwa/setup.php"
