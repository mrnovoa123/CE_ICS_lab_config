#!/usr/bin/env bash
# provision/suricata-homenet.sh — define qué es "red de confianza" (HOME_NET) para Suricata en siem.
#
#   sudo bash suricata-homenet.sh activos   # (por defecto) HOME_NET = solo siem, win10 y srvweb
#                                            #   → Kali (.100) queda en EXTERNAL_NET y SÍ saltan las reglas ET
#   sudo bash suricata-homenet.sh red       # VOLVER ATRÁS: HOME_NET = toda la red /24 (comportamiento anterior)
#                                            #   → Kali queda dentro de HOME_NET y las reglas ET $EXTERNAL_NET→$HOME_NET NO saltan
#
# Detecta solo la red del laboratorio: 10.10.10.x (casa/Vagrant) o 172.21.10.x (aula).
# Antes de tocar nada guarda una copia: /etc/suricata/suricata.yaml.bak-AAAAMMDD-HHMMSS
set -euo pipefail
MODO="${1:-activos}"
CONF=/etc/suricata/suricata.yaml
P=$(ip -o -4 addr show | grep -oE '(10\.10\.10|172\.21\.10)\.[0-9]+' | head -1 | cut -d. -f1-3)
[ -n "$P" ] || { echo "No encuentro la red del laboratorio (10.10.10.x / 172.21.10.x)"; exit 1; }

case "$MODO" in
  activos) VAL="[${P}.10,${P}.20,${P}.30]" ;;
  red)     VAL="[${P}.0/24]" ;;
  *) echo "Uso: $0 activos|red"; exit 1 ;;
esac

cp -a "$CONF" "${CONF}.bak-$(date +%Y%m%d-%H%M%S)"
sed -i "s|^\(\s*\)HOME_NET:.*|\1HOME_NET: \"${VAL}\"|" "$CONF"
sed -i "s|^\(\s*\)EXTERNAL_NET:.*|\1EXTERNAL_NET: \"!\$HOME_NET\"|" "$CONF"

suricata -T -c "$CONF" -q && systemctl restart suricata
echo "Suricata: modo '${MODO}' → HOME_NET=${VAL} · EXTERNAL_NET=!\$HOME_NET"
grep -nE '^\s*(HOME_NET|EXTERNAL_NET):' "$CONF"
