#!/usr/bin/env bash
set -euo pipefail

APP="Semaphore"
INSTALL_DIR="/opt/semaphore"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_NAME="${ADMIN_NAME:-Administrator}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"

apt update
apt install -y curl wget gnupg ca-certificates sqlite3 openssl

mkdir -p "$INSTALL_DIR/tmp"
cd /tmp

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64) SEM_ARCH="amd64" ;;
  arm64) SEM_ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

LATEST_URL="$(curl -fsSL https://api.github.com/repos/semaphoreui/semaphore/releases/latest \
  | grep "browser_download_url" \
  | grep "linux_${SEM_ARCH}.deb" \
  | cut -d '"' -f 4 \
  | head -n1)"

if [[ -z "$LATEST_URL" ]]; then
  echo "Nie znaleziono paczki Semaphore dla architektury: $SEM_ARCH"
  exit 1
fi

wget -O semaphore.deb "$LATEST_URL"
apt install -y ./semaphore.deb

cat > "$INSTALL_DIR/config.json" <<EOF
{
  "bolt": {},
  "postgres": {},
  "mysql": {},
  "sqlite": {
    "host": "$INSTALL_DIR/database.sqlite"
  },
  "dialect": "sqlite",
  "tmp_path": "$INSTALL_DIR/tmp",
  "cookie_hash": "$(openssl rand -hex 32)",
  "cookie_encryption": "$(openssl rand -hex 16)",
  "access_key_encryption": "$(openssl rand -hex 16)",
  "email_sender": "",
  "email_host": "",
  "email_port": "",
  "email_username": "",
  "email_password": "",
  "web_host": "",
  "ldap_enable": false,
  "ldap_binddn": "",
  "ldap_bindpassword": "",
  "ldap_server": "",
  "ldap_searchdn": "",
  "ldap_searchfilter": "",
  "ldap_mappings": {
    "dn": "",
    "mail": "",
    "uid": "",
    "cn": ""
  },
  "telegram_chat": "",
  "telegram_token": "",
  "slack_url": "",
  "max_parallel_tasks": 0,
  "email_alert": false,
  "telegram_alert": false,
  "slack_alert": false,
  "ssh_config_path": "",
  "demo_mode": false
}
EOF

cat > /etc/systemd/system/semaphore.service <<EOF
[Unit]
Description=Semaphore UI
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/semaphore server --config $INSTALL_DIR/config.json
Restart=always
User=root
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# Inicjalizacja bazy danych
semaphore migrate --config "$INSTALL_DIR/config.json" || true

# Utworzenie konta administratora, jeśli nie istnieje
if ! semaphore user list --config "$INSTALL_DIR/config.json" 2>/dev/null | grep -q "$ADMIN_USER"; then
  semaphore user add \
    --config "$INSTALL_DIR/config.json" \
    --admin \
    --login "$ADMIN_USER" \
    --name "$ADMIN_NAME" \
    --email "$ADMIN_EMAIL" \
    --password "$ADMIN_PASSWORD"
fi

systemctl enable --now semaphore

IP="$(hostname -I | awk '{print $1}')"

echo ""
echo "=========================================="
echo "$APP został zainstalowany."
echo "Adres GUI: http://${IP}:3000"
echo ""
echo "Login: $ADMIN_USER"
echo "Hasło: $ADMIN_PASSWORD"
echo "=========================================="
