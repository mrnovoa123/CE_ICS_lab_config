# CE_ICS_lab_config

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

## Snapshots
```bash
vagrant halt
vagrant snapshot save siem base-limpia    # repetir para srvweb, kali, win10
vagrant snapshot restore srvweb base-limpia
```

Manual completo: documento «Manual Vagrant – Laboratorio MP5021».
