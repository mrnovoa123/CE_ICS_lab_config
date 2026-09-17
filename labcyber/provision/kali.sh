#!/usr/bin/env bash
# provision/kali.sh — herramientas del atacante
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Clave del repositorio de Kali (las boxes antiguas traen la clave caducada)
wget -q https://archive.kali.org/archive-keyring.gpg -O /usr/share/keyrings/kali-archive-keyring.gpg

apt-get update
apt-get install -y -o Dpkg::Options::="--force-confold" \
  nmap hydra hping3 sqlmap nikto wordlists curl tcpdump

# Diccionario rockyou descomprimido (t2.3)
[ -f /usr/share/wordlists/rockyou.txt ] || gunzip -k /usr/share/wordlists/rockyou.txt.gz

# Nombres de las máquinas del laboratorio
grep -q "10.10.10.30  srvweb" /etc/hosts || cat >> /etc/hosts <<'EOF'
10.10.10.10  siem
10.10.10.20  win10
10.10.10.30  srvweb
EOF
echo "kali listo"
