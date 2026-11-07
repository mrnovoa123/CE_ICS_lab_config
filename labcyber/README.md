# Laboratorio MP5021 — labcyber (Vagrant + VirtualBox)

| VM | Rol | LAN labcyber-lan | Gestión host-only |
|---|---|---|---|
| siem | Wazuh all-in-one + Suricata | 10.10.10.10 | 192.168.56.10 |
| win10 | Víctima Windows + Sysmon (autostart: false) | 10.10.10.20 | 192.168.56.20 |
| srvweb | Víctima LAMP + DVWA | 10.10.10.30 | 192.168.56.30 |
| kali | Atacante | 10.10.10.100 | 192.168.56.100 |

## Puesta en marcha
```bash
cd labcyber
vagrant validate
vagrant up siem          # primero el manager (15-25 min)
vagrant up srvweb kali
vagrant up win10         # solo si hace falta
```

- Panel Wazuh: https://192.168.56.10 — usuario `admin`, contraseña en `wazuh-passwords.txt` (se crea en esta carpeta).
- DVWA: http://192.168.56.30/dvwa/setup.php → Create/Reset Database → login `admin` / `password`.
- Usuario SSH débil en srvweb: `empleado` / `123456`.
- Kali y win10: `vagrant` / `vagrant`.

## Antes de usar
- Comprueba la versión de Wazuh en https://documentation.wazuh.com/current/quickstart.html y ajusta
  `WAZUH_BRANCH` y `WAZUH_AGENT_VER` al principio del Vagrantfile (el agente nunca mayor que el manager).
- Los `.sh` deben tener finales de línea LF (si los editas en Windows).

## Suricata: HOME_NET solo con los activos (cambio de nov-2026)

**Qué cambia.** `provision/siem.sh` ya no pone en `HOME_NET` toda la red (`10.10.10.0/24`), sino solo los
activos protegidos: `[10.10.10.10,10.10.10.20,10.10.10.30]` (siem, win10, srvweb). `EXTERNAL_NET` queda
como `!$HOME_NET`.

**Por qué.** Kali (`.100`) estaba dentro de `HOME_NET`, así que las reglas de Emerging Threats
(`$EXTERNAL_NET -> $HOME_NET`) **no saltaban** con sus escaneos y ataques; solo saltaban las `local.rules`
escritas con `any`. Ahora Kali es «externo» y esas reglas **sí saltan**.

**Aplicarlo en una VM ya creada** (o en el aula, red 172.21.10.x — el script detecta la red solo):
```bash
sudo bash /vagrant/provision/suricata-homenet.sh activos
```

**Volver atrás** (HOME_NET = toda la red, comportamiento anterior):
```bash
sudo bash /vagrant/provision/suricata-homenet.sh red
# o restaurar la copia que deja el script:
sudo cp /etc/suricata/suricata.yaml.bak-AAAAMMDD-HHMMSS /etc/suricata/suricata.yaml && sudo systemctl restart suricata
```
En una VM importada desde OVA (aula) no existe `/vagrant`: copia antes `provision/suricata-homenet.sh` a la VM.
Comprobación: desde Kali `nmap -sS -p- <IP de srvweb>` → en siem `sudo tail -f /var/log/suricata/fast.log`
deben aparecer firmas `ET SCAN`.

## Snapshots
```bash
vagrant halt
vagrant snapshot save siem base-limpia    # repetir para srvweb, kali, win10
vagrant snapshot restore srvweb base-limpia
```

Manual completo: documento «Manual Vagrant – Laboratorio MP5021».
