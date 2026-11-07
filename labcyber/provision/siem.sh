#!/usr/bin/env bash
# provision/siem.sh — Wazuh all-in-one + Suricata
set -euo pipefail
BRANCH="${1:-4.14}"
export DEBIAN_FRONTEND=noninteractive
LAN_IF=$(ip -o -4 addr show | awk '/ 10\.10\.10\./{print $2; exit}')

apt-get update
apt-get install -y curl software-properties-common

# --- 1. Wazuh (indexer + manager + dashboard en una sola VM) ---
cd /root
curl -sO "https://packages.wazuh.com/${BRANCH}/wazuh-install.sh"
bash ./wazuh-install.sh -a -i | tee /root/wazuh-install.log   # -i: omite la comprobación de requisitos
tar -O -xf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt > /vagrant/wazuh-passwords.txt

# --- 2. Suricata escuchando en la LAN del laboratorio ---
add-apt-repository -y ppa:oisf/suricata-stable
apt-get update
apt-get install -y suricata
CONF=/etc/suricata/suricata.yaml
# HOME_NET = solo los activos protegidos (siem .10, win10 .20, srvweb .30).
# Kali (.100) queda FUERA → en EXTERNAL_NET → las reglas ET ($EXTERNAL_NET -> $HOME_NET) SÍ saltan con sus ataques.
# Antes era HOME_NET "[10.10.10.0/24]" (Kali dentro): solo saltaban las reglas locales escritas con "any".
# Volver atrás (en la VM ya creada):  sudo bash /vagrant/provision/suricata-homenet.sh red
sed -i "s|^\(\s*HOME_NET:\).*|\1 \"[10.10.10.10,10.10.10.20,10.10.10.30]\"|" "$CONF"
sed -i "s|^\(\s*EXTERNAL_NET:\).*|\1 \"!\$HOME_NET\"|" "$CONF"
sed -i "s|interface: eth0|interface: ${LAN_IF}|g" "$CONF"
[ -f /etc/default/suricata ] && sed -i "s|^IFACE=.*|IFACE=${LAN_IF}|" /etc/default/suricata

# Reglas propias para las prácticas
mkdir -p /etc/suricata/rules
cat > /etc/suricata/rules/local.rules <<'EOF'
alert icmp any any -> $HOME_NET any (msg:"LAB ICMP echo hacia la LAN"; itype:8; sid:1000001; rev:1;)
alert tcp any any -> $HOME_NET 22 (msg:"LAB intento de conexion SSH"; flags:S; sid:1000002; rev:1;)
EOF
grep -q local.rules "$CONF" || sed -i 's|^\(\s*\)- suricata.rules|\1- suricata.rules\n\1- /etc/suricata/rules/local.rules|' "$CONF"
suricata-update
systemctl enable suricata && systemctl restart suricata

# --- 3. Wazuh lee las alertas de Suricata ---
grep -q suricata/eve.json /var/ossec/etc/ossec.conf || cat >> /var/ossec/etc/ossec.conf <<'EOF'

<ossec_config>
  <localfile>
    <log_format>json</log_format>
    <location>/var/log/suricata/eve.json</location>
  </localfile>
</ossec_config>
EOF
systemctl restart wazuh-manager
echo "SIEM listo: https://192.168.56.10 (credenciales en labcyber/wazuh-passwords.txt)"
