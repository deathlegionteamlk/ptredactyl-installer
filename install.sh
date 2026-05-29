#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

NOOK_PANEL_URL="https://github.com/Nookure/NookTheme/releases/latest/download/panel.tar.gz"
WINGS_VERSION="1.11.13"
PHP_VERSION="8.3"
NODE_VERSION="20"
PANEL_DIR="/var/www/pterodactyl"
WINGS_DIR="/etc/pterodactyl"
INSTALL_LOG="/var/log/ptero-install.log"
ZONEID_API="https://my.zone.id/api"
SUMMARY_FILE="/root/ptero-credentials.txt"

exec > >(tee -a "$INSTALL_LOG") 2>&1

gen_pass()  { openssl rand -base64 20 | tr -d '/+=' | cut -c1-20; }
gen_token() { openssl rand -hex 32; }

log_info()    { echo -e "${GREEN}[✔]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1"; }
log_step()    { echo -e "\n${CYAN}[→]${NC} ${BOLD}$1${NC}"; }
log_success() { echo -e "${GREEN}${BOLD}[✔✔] $1${NC}"; }
log_dim()     { echo -e "${DIM}    $1${NC}"; }

print_banner() {
  clear
  echo -e "${PURPLE}"
  cat << 'BANNER'
  ╔══════════════════════════════════════════════════════════════╗
  ║                                                              ║
  ║    ██████╗ ████████╗███████╗██████╗  ██████╗               ║
  ║    ██╔══██╗╚══██╔══╝██╔════╝██╔══██╗██╔═══██╗              ║
  ║    ██████╔╝   ██║   █████╗  ██████╔╝██║   ██║              ║
  ║    ██╔═══╝    ██║   ██╔══╝  ██╔══██╗██║   ██║              ║
  ║    ██║        ██║   ███████╗██║  ██║╚██████╔╝              ║
  ║    ╚═╝        ╚═╝   ╚══════╝╚═╝  ╚═╝ ╚═════╝              ║
  ║                                                              ║
  ║         + NookTheme  |  Auto Installer  v2.0                ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
BANNER
  echo -e "${NC}"
  echo -e "${WHITE}${BOLD}         by demo x hexa  ·  github.com/Deathlegionteamlk${NC}"
  echo -e "${DIM}         Zone.id DNS auto-config  ·  All eggs  ·  NookTheme${NC}"
  echo ""
}

check_root() {
  if [ "$EUID" -ne 0 ]; then
    log_error "Must run as root. Use: sudo bash install.sh"
    exit 1
  fi
}

detect_os() {
  if [ ! -f /etc/os-release ]; then
    log_error "Cannot detect OS."
    exit 1
  fi
  . /etc/os-release
  OS_ID="$ID"
  OS_VER="$VERSION_ID"

  case "$OS_ID" in
    ubuntu) [[ "$OS_VER" =~ ^(20\.04|22\.04|24\.04)$ ]] || { log_error "Ubuntu $OS_VER not supported."; exit 1; } ;;
    debian) [[ "$OS_VER" =~ ^(11|12)$ ]] || { log_error "Debian $OS_VER not supported."; exit 1; } ;;
    *) log_error "Unsupported OS: $OS_ID. Use Ubuntu 20.04/22.04/24.04 or Debian 11/12."; exit 1 ;;
  esac

  log_info "OS: $OS_ID $OS_VER"
}

detect_server_ip() {
  SERVER_IP=$(curl -sf https://api.ipify.org || curl -sf https://ifconfig.me || hostname -I | awk '{print $1}')
  log_info "Server IP: $SERVER_IP"
}

collect_inputs() {
  echo ""
  echo -e "${BOLD}${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}${WHITE}  SETUP — enter domains (all passwords auto-generated)${NC}"
  echo -e "${BOLD}${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  echo -ne "${CYAN}[?]${NC} Panel domain ${DIM}(e.g. panel.zone.id or panel.yourdomain.com)${NC}: "
  read -r PANEL_FQDN
  PANEL_FQDN="${PANEL_FQDN:-panel.example.zone.id}"

  echo -ne "${CYAN}[?]${NC} Wings/Node domain ${DIM}(e.g. node1.zone.id or node1.yourdomain.com)${NC}: "
  read -r WINGS_FQDN
  WINGS_FQDN="${WINGS_FQDN:-node1.example.zone.id}"

  echo -ne "${CYAN}[?]${NC} Admin email ${DIM}[default: admin@${PANEL_FQDN}]${NC}: "
  read -r ADMIN_EMAIL
  ADMIN_EMAIL="${ADMIN_EMAIL:-admin@${PANEL_FQDN}}"

  echo ""
  echo -e "${BOLD}${WHITE}  ZONE.ID DNS AUTO-CONFIG${NC}"
  echo -e "${DIM}  Zone.id gives free subdomains (e.g. yourname.zone.id).${NC}"
  echo -e "${DIM}  Get your Bearer token: login at my.zone.id → DevTools → Network → copy Authorization header.${NC}"
  echo ""
  echo -ne "${CYAN}[?]${NC} Zone.id Bearer token ${DIM}(leave blank to skip DNS auto-config)${NC}: "
  read -rs ZONEID_TOKEN
  echo ""

  if [ -n "$ZONEID_TOKEN" ]; then
    echo -ne "${CYAN}[?]${NC} Override server IP? ${DIM}[default: $SERVER_IP]${NC}: "
    read -r OVERRIDE_IP
    SERVER_IP="${OVERRIDE_IP:-$SERVER_IP}"
  fi

  echo ""
  echo -e "${BOLD}${WHITE}  NODE CONFIG${NC}"
  echo ""
  echo -ne "${CYAN}[?]${NC} Node name ${DIM}[default: Node-01]${NC}: "
  read -r NODE_NAME
  NODE_NAME="${NODE_NAME:-Node-01}"

  echo -ne "${CYAN}[?]${NC} Location code ${DIM}[default: ID-JKT]${NC}: "
  read -r NODE_LOCATION
  NODE_LOCATION="${NODE_LOCATION:-ID-JKT}"

  ADMIN_USER="admin"
  ADMIN_FIRST="Admin"
  ADMIN_LAST="User"
  ADMIN_PASS=$(gen_pass)
  DB_NAME="pterodactyl"
  DB_USER="pterodactyl"
  DB_PASS=$(gen_pass)
  DB_ROOT_PASS=$(gen_pass)
  WINGS_PORT=8080
  WINGS_SFTP_PORT=2022

  echo ""
  echo -e "${GREEN}${BOLD}[✔] Configuration complete. Starting fully autonomous installation...${NC}"
  echo ""
}

zoneid_list_subdomains() {
  curl -sf -X GET \
    -H "Authorization: Bearer ${ZONEID_TOKEN}" \
    -H "Accept: application/json" \
    "${ZONEID_API}/subdomains"
}

zoneid_get_subdomains_dns() {
  local sub_id="$1"
  curl -sf -X GET \
    -H "Authorization: Bearer ${ZONEID_TOKEN}" \
    -H "Accept: application/json" \
    "${ZONEID_API}/subdomains/${sub_id}/dns"
}

zoneid_upsert_a_record() {
  local sub_id="$1"
  local ip="$2"
  local fqdn="$3"

  local existing_record_id
  existing_record_id=$(zoneid_get_subdomains_dns "$sub_id" 2>/dev/null | \
    jq -r '.data // .records // [] | .[] | select(.type=="A" and (.hostname=="@" or .hostname=="")) | .id' 2>/dev/null | head -1)

  if [ -n "$existing_record_id" ] && [ "$existing_record_id" != "null" ]; then
    local result
    result=$(curl -sf -X PUT \
      -H "Authorization: Bearer ${ZONEID_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "{\"type\":\"A\",\"hostname\":\"@\",\"content\":\"${ip}\"}" \
      "${ZONEID_API}/subdomains/${sub_id}/dns/${existing_record_id}")
    log_info "Zone.id A record updated: $fqdn → $ip"
  else
    local result
    result=$(curl -sf -X POST \
      -H "Authorization: Bearer ${ZONEID_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "{\"type\":\"A\",\"hostname\":\"@\",\"content\":\"${ip}\"}" \
      "${ZONEID_API}/subdomains/${sub_id}/dns")
    log_info "Zone.id A record created: $fqdn → $ip"
  fi
}

configure_zoneid_dns() {
  if [ -z "$ZONEID_TOKEN" ]; then
    log_warn "Zone.id token not provided. Configure DNS manually before SSL issuance."
    return 0
  fi

  log_step "Configuring Zone.id DNS records..."

  local subs_json
  subs_json=$(zoneid_list_subdomains 2>/dev/null)

  if [ -z "$subs_json" ]; then
    log_error "Zone.id API call failed. Check your Bearer token."
    log_warn "Continuing without DNS auto-config."
    return 1
  fi

  local panel_id
  panel_id=$(echo "$subs_json" | jq -r \
    ".data // .subdomains // [] | .[] | select(.name==\"${PANEL_FQDN}\" or (.name + \".zone.id\")==\"${PANEL_FQDN}\") | .id" 2>/dev/null | head -1)

  local wings_id
  wings_id=$(echo "$subs_json" | jq -r \
    ".data // .subdomains // [] | .[] | select(.name==\"${WINGS_FQDN}\" or (.name + \".zone.id\")==\"${WINGS_FQDN}\") | .id" 2>/dev/null | head -1)

  if [ -z "$panel_id" ] || [ "$panel_id" = "null" ]; then
    log_warn "Subdomain '$PANEL_FQDN' not found in Zone.id. Register it at my.zone.id first."
    log_dim "Available subdomains:"
    echo "$subs_json" | jq -r '.data // .subdomains // [] | .[].name' 2>/dev/null | while read -r n; do log_dim "  - $n"; done
  else
    zoneid_upsert_a_record "$panel_id" "$SERVER_IP" "$PANEL_FQDN"
  fi

  if [ -z "$wings_id" ] || [ "$wings_id" = "null" ]; then
    log_warn "Subdomain '$WINGS_FQDN' not found in Zone.id. Register it at my.zone.id first."
  else
    zoneid_upsert_a_record "$wings_id" "$SERVER_IP" "$WINGS_FQDN"
  fi

  log_info "Waiting 15s for DNS propagation..."
  sleep 15
}

install_base_deps() {
  log_step "Installing base packages..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y -q
  apt-get upgrade -y -q -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
  apt-get install -y -q \
    curl wget git unzip tar \
    software-properties-common apt-transport-https ca-certificates gnupg lsb-release \
    openssl certbot python3-certbot-nginx \
    redis-server supervisor cron jq \
    mariadb-server mariadb-client \
    nginx
  systemctl enable redis-server mariadb nginx
  systemctl start redis-server mariadb
  log_info "Base packages installed."
}

install_php() {
  log_step "Installing PHP $PHP_VERSION..."
  if [ "$OS_ID" = "ubuntu" ]; then
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php >/dev/null 2>&1
  else
    curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/php-sury.gpg 2>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/php-sury.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
      > /etc/apt/sources.list.d/php-sury.list
  fi
  apt-get update -y -q
  apt-get install -y -q \
    "php${PHP_VERSION}" "php${PHP_VERSION}-cli" "php${PHP_VERSION}-common" \
    "php${PHP_VERSION}-gd" "php${PHP_VERSION}-mysql" "php${PHP_VERSION}-mbstring" \
    "php${PHP_VERSION}-bcmath" "php${PHP_VERSION}-xml" "php${PHP_VERSION}-curl" \
    "php${PHP_VERSION}-zip" "php${PHP_VERSION}-intl" "php${PHP_VERSION}-fpm" \
    "php${PHP_VERSION}-tokenizer" "php${PHP_VERSION}-fileinfo" "php${PHP_VERSION}-redis"
  log_info "PHP $PHP_VERSION ready."
}

install_composer() {
  log_step "Installing Composer..."
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >/dev/null 2>&1
  log_info "Composer: $(composer --version 2>/dev/null | head -1 | awk '{print $3}')"
}

install_nodejs() {
  log_step "Installing Node.js $NODE_VERSION LTS..."
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - >/dev/null 2>&1
  apt-get install -y -q nodejs
  npm install -g npm@latest yarn >/dev/null 2>&1
  log_info "Node.js $(node -v) | npm $(npm -v) | yarn $(yarn -v 2>/dev/null)"
}

install_docker() {
  log_step "Installing Docker..."
  if command -v docker &>/dev/null; then
    log_info "Docker already installed: $(docker --version | awk '{print $3}' | tr -d ',')"
    return 0
  fi
  curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
  systemctl enable docker
  systemctl start docker
  log_info "Docker: $(docker --version | awk '{print $3}' | tr -d ',')"
}

setup_mariadb() {
  log_step "Configuring MariaDB..."
  mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';" 2>/dev/null || true
  mysql -u root -p"${DB_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;" 2>/dev/null || \
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
  mysql -u root -p"${DB_ROOT_PASS}" -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null || \
    mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
  mysql -u root -p"${DB_ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';" 2>/dev/null || \
    mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';"
  mysql -u root -p"${DB_ROOT_PASS}" -e "FLUSH PRIVILEGES;" 2>/dev/null || \
    mysql -u root -e "FLUSH PRIVILEGES;"
  log_info "MariaDB: database=${DB_NAME} user=${DB_USER}"
}

issue_ssl() {
  local domain="$1"
  log_step "Issuing SSL for ${domain}..."
  systemctl stop nginx 2>/dev/null || true
  certbot certonly --standalone --non-interactive --agree-tos \
    --email "$ADMIN_EMAIL" -d "$domain" 2>&1 | tail -3
  systemctl start nginx 2>/dev/null || true
  if [ ! -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]; then
    log_warn "SSL for $domain failed. DNS may not have propagated. Continuing..."
    return 1
  fi
  log_info "SSL ready for $domain."
}

install_nooktheme() {
  log_step "Downloading NookTheme (Pterodactyl + Nook skin)..."
  mkdir -p "$PANEL_DIR"
  cd "$PANEL_DIR" || exit 1

  curl -sSL "$NOOK_PANEL_URL" -o panel.tar.gz
  tar -xzf panel.tar.gz
  rm -f panel.tar.gz

  chmod -R 755 storage bootstrap/cache
  chown -R www-data:www-data "$PANEL_DIR"

  log_step "Installing NookTheme PHP dependencies..."
  cp .env.example .env
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader -q

  log_step "Configuring environment..."
  php artisan key:generate --force

  sed -i "s|APP_URL=.*|APP_URL=https://${PANEL_FQDN}|" .env
  sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
  sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" .env
  sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env
  sed -i "s|DB_HOST=.*|DB_HOST=127.0.0.1|" .env
  sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=redis|" .env
  sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=redis|" .env
  sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|" .env
  sed -i "s|APP_ENV=.*|APP_ENV=production|" .env
  sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|" .env
  sed -i "s|MAIL_FROM_ADDRESS=.*|MAIL_FROM_ADDRESS=noreply@${PANEL_FQDN}|" .env
  sed -i "s|APP_TIMEZONE=.*|APP_TIMEZONE=Asia/Jakarta|" .env

  log_step "Running migrations + seeding..."
  php artisan migrate --seed --force

  log_step "Clearing caches..."
  php artisan view:clear
  php artisan config:clear
  php artisan route:cache

  log_step "Creating admin account..."
  php artisan p:user:make \
    --email="$ADMIN_EMAIL" \
    --username="$ADMIN_USER" \
    --name-first="$ADMIN_FIRST" \
    --name-last="$ADMIN_LAST" \
    --password="$ADMIN_PASS" \
    --admin=1

  chown -R www-data:www-data "$PANEL_DIR"
  log_info "NookTheme Panel installed."
}

configure_nginx() {
  log_step "Writing Nginx config..."

  local ssl_cert="/etc/letsencrypt/live/${PANEL_FQDN}/fullchain.pem"
  local ssl_key="/etc/letsencrypt/live/${PANEL_FQDN}/privkey.pem"

  if [ ! -f "$ssl_cert" ]; then
    ssl_cert="/etc/ssl/certs/ssl-cert-snakeoil.pem"
    ssl_key="/etc/ssl/private/ssl-cert-snakeoil.key"
    apt-get install -y -q ssl-cert >/dev/null 2>&1
    log_warn "Using self-signed cert for panel (SSL issuance failed)."
  fi

  cat > /etc/nginx/sites-available/pterodactyl.conf << NGINXCFG
server {
    listen 80;
    server_name ${PANEL_FQDN};
    return 301 https://\$server_name\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name ${PANEL_FQDN};
    root ${PANEL_DIR}/public;
    index index.php;
    access_log /var/log/nginx/pterodactyl.access.log;
    error_log  /var/log/nginx/pterodactyl.error.log error;
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;
    ssl_certificate     ${ssl_cert};
    ssl_certificate_key ${ssl_key};
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize=100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    location ~ /\.ht { deny all; }
}
NGINXCFG

  ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx
  log_info "Nginx configured."
}

configure_supervisor() {
  log_step "Configuring queue workers..."
  cat > /etc/supervisor/conf.d/pterodactyl-worker.conf << SUPERCFG
[program:pterodactyl-worker]
process_name=%(program_name)s_%(process_num)02d
command=php ${PANEL_DIR}/artisan queue:work --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/log/ptero-worker.log
stopwaitsecs=3600
SUPERCFG
  supervisorctl reread >/dev/null 2>&1
  supervisorctl update >/dev/null 2>&1
  supervisorctl start pterodactyl-worker:* >/dev/null 2>&1
  log_info "Queue workers started."
}

configure_cron() {
  (crontab -u www-data -l 2>/dev/null | grep -v pterodactyl; \
    echo "* * * * * php ${PANEL_DIR}/artisan schedule:run >> /dev/null 2>&1") \
    | crontab -u www-data -
  log_info "Cron job configured."
}

install_wings() {
  log_step "Installing Wings v${WINGS_VERSION}..."
  mkdir -p "$WINGS_DIR"
  local arch
  arch=$(uname -m)
  local bin="wings_linux_amd64"
  [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ] && bin="wings_linux_arm64"

  curl -sSL "https://github.com/pterodactyl/wings/releases/download/v${WINGS_VERSION}/${bin}" \
    -o /usr/local/bin/wings
  chmod +x /usr/local/bin/wings

  cat > /etc/systemd/system/wings.service << WINGSVC
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service
[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s
[Install]
WantedBy=multi-user.target
WINGSVC

  systemctl daemon-reload
  systemctl enable wings
  log_info "Wings binary ready."
}

create_location_and_node() {
  log_step "Creating Panel location + node..."
  cd "$PANEL_DIR" || exit 1

  LOCATION_ID=$(php artisan tinker --no-interaction 2>/dev/null << 'TINKER1' | grep -oP '(?<=loc:)\d+' | head -1
$l = new \Pterodactyl\Models\Location();
$l->short = getenv('NODE_LOCATION') ?: 'ID-JKT';
$l->long = 'Auto-created';
$l->save();
echo 'loc:' . $l->id;
TINKER1
)
  export NODE_LOCATION
  LOCATION_ID=$(NODE_LOCATION="$NODE_LOCATION" php artisan tinker --no-interaction 2>/dev/null << TINKER1B | grep -oP '(?<=loc:)\d+' | head -1
\$l = new \Pterodactyl\Models\Location();
\$l->short = '${NODE_LOCATION}';
\$l->long = 'Auto-created by installer';
\$l->save();
echo 'loc:' . \$l->id;
TINKER1B
)
  LOCATION_ID="${LOCATION_ID:-1}"

  local mem_mb disk_mb
  mem_mb=$(free -m | awk '/^Mem:/{print int($2 * 0.80)}')
  disk_mb=$(df -BM / | awk 'NR==2{gsub("M",""); print int($4 * 0.80)}')

  NODE_ID=$(php artisan tinker --no-interaction 2>/dev/null << TINKER2 | grep -oP '(?<=node:)\d+' | head -1
\$n = new \Pterodactyl\Models\Node();
\$n->name = '${NODE_NAME}';
\$n->location_id = ${LOCATION_ID};
\$n->fqdn = '${WINGS_FQDN}';
\$n->scheme = 'https';
\$n->memory = ${mem_mb};
\$n->memory_overallocate = 0;
\$n->disk = ${disk_mb};
\$n->disk_overallocate = 0;
\$n->upload_size = 100;
\$n->daemonListen = ${WINGS_PORT};
\$n->daemonSFTP = ${WINGS_SFTP_PORT};
\$n->maintenance_mode = false;
\$n->public = true;
\$n->daemon_token = \Illuminate\Support\Str::random(36);
\$n->daemon_token_id = \Illuminate\Support\Str::random(16);
\$n->save();
echo 'node:' . \$n->id;
TINKER2
)
  NODE_ID="${NODE_ID:-1}"
  log_info "Location ID: $LOCATION_ID | Node ID: $NODE_ID"
}

configure_wings_config() {
  log_step "Generating Wings config from Panel..."
  cd "$PANEL_DIR" || exit 1

  php artisan p:node:configuration "$NODE_ID" > "$WINGS_DIR/config.yml" 2>/dev/null

  if [ ! -s "$WINGS_DIR/config.yml" ]; then
    local tok tok_id
    tok=$(php artisan tinker --no-interaction 2>/dev/null << TINKER3 | grep -oP '(?<=tok:).+' | head -1
\$n = \Pterodactyl\Models\Node::find(${NODE_ID});
echo 'tok:' . \$n->daemon_token;
TINKER3
)
    tok_id=$(php artisan tinker --no-interaction 2>/dev/null << TINKER4 | grep -oP '(?<=tid:).+' | head -1
\$n = \Pterodactyl\Models\Node::find(${NODE_ID});
echo 'tid:' . \$n->daemon_token_id;
TINKER4
)

    local ssl_cert="/etc/letsencrypt/live/${WINGS_FQDN}/fullchain.pem"
    local ssl_key="/etc/letsencrypt/live/${WINGS_FQDN}/privkey.pem"
    [ ! -f "$ssl_cert" ] && ssl_cert="/etc/ssl/certs/ssl-cert-snakeoil.pem" && ssl_key="/etc/ssl/private/ssl-cert-snakeoil.key"

    cat > "$WINGS_DIR/config.yml" << WINGSCFG
debug: false
uuid: auto
token_id: "${tok_id}"
token: "${tok}"
api:
  host: 0.0.0.0
  port: ${WINGS_PORT}
  ssl:
    enabled: true
    cert: ${ssl_cert}
    key: ${ssl_key}
  upload_limit: 100
system:
  data: /var/lib/pterodactyl/volumes
  sftp:
    bind_port: ${WINGS_SFTP_PORT}
allowed_mounts: []
remote: https://${PANEL_FQDN}
WINGSCFG
  fi

  mkdir -p /var/lib/pterodactyl/volumes /var/log/pterodactyl
  log_info "Wings config written."
}

create_allocations() {
  log_step "Creating default port allocations..."
  cd "$PANEL_DIR" || exit 1
  for port in 25565 25566 25567 25568 25569 27015 27016 27017 7777 7778 2456 2457 30120 30121 19132 19133; do
    php artisan tinker --no-interaction 2>/dev/null << ALLOC >/dev/null
\$a = new \Pterodactyl\Models\Allocation();
\$a->node_id = ${NODE_ID};
\$a->ip = '0.0.0.0';
\$a->port = ${port};
\$a->save();
ALLOC
  done
  log_info "Port allocations created: 25565-25569, 27015-27017, 7777-7778, 2456-2457, 30120-30121, 19132-19133"
}

import_all_eggs() {
  log_step "Importing all official Pterodactyl eggs..."
  cd "$PANEL_DIR" || exit 1

  local egg_tmp="/tmp/ptero-eggs-$$"
  git clone --depth 1 --quiet https://github.com/pterodactyl/eggs.git "$egg_tmp" 2>&1 | tail -1

  local ok=0 fail=0

  while IFS= read -r -d '' egg_json; do
    local nest_dir
    nest_dir=$(basename "$(dirname "$(dirname "$egg_json")")")

    local nest_id
    nest_id=$(php artisan tinker --no-interaction 2>/dev/null << NESTTINKER | grep -oP '(?<=nid:)\d+' | head -1
\$n = \Pterodactyl\Models\Nest::firstOrCreate(['name' => '${nest_dir}'], ['description' => 'Auto-imported', 'author' => 'support@pterodactyl.io']);
echo 'nid:' . \$n->id;
NESTTINKER
)

    if [ -n "$nest_id" ]; then
      if php artisan p:egg:import --nest="$nest_id" --file="$egg_json" 2>/dev/null; then
        ((ok++))
      else
        ((fail++))
      fi
    fi
  done < <(find "$egg_tmp" -name "egg-*.json" -print0 2>/dev/null)

  rm -rf "$egg_tmp"
  log_success "Eggs: $ok imported, $fail skipped."
}

start_wings() {
  log_step "Starting Wings..."
  systemctl start wings
  sleep 5
  if systemctl is-active --quiet wings; then
    log_success "Wings is running."
  else
    log_warn "Wings failed to start. Run: journalctl -u wings -n 50"
  fi
}

save_credentials() {
  cat > "$SUMMARY_FILE" << CREDS
═══════════════════════════════════════════════════════════════
  PTERODACTYL + NOOKTHEME — INSTALLATION CREDENTIALS
  by demo x hexa | github.com/Deathlegionteamlk
  Generated: $(date)
═══════════════════════════════════════════════════════════════

  PANEL
  ─────────────────────────────────────────────────────────────
  URL          : https://${PANEL_FQDN}
  Admin Email  : ${ADMIN_EMAIL}
  Admin User   : ${ADMIN_USER}
  Admin Pass   : ${ADMIN_PASS}

  DATABASE
  ─────────────────────────────────────────────────────────────
  DB Name      : ${DB_NAME}
  DB User      : ${DB_USER}
  DB Password  : ${DB_PASS}
  DB Root Pass : ${DB_ROOT_PASS}
  DB Host      : 127.0.0.1:3306

  WINGS / NODE
  ─────────────────────────────────────────────────────────────
  Wings URL    : https://${WINGS_FQDN}:${WINGS_PORT}
  SFTP Port    : ${WINGS_SFTP_PORT}
  Node ID      : ${NODE_ID}
  Location ID  : ${LOCATION_ID}
  Node Name    : ${NODE_NAME}

  SERVER
  ─────────────────────────────────────────────────────────────
  Server IP    : ${SERVER_IP}
  Install Log  : ${INSTALL_LOG}

  USEFUL COMMANDS
  ─────────────────────────────────────────────────────────────
  systemctl status wings
  journalctl -u wings -f
  supervisorctl status pterodactyl-worker:*
  certbot certificates
  mysql -u root -p${DB_ROOT_PASS}

═══════════════════════════════════════════════════════════════
CREDS
  chmod 600 "$SUMMARY_FILE"
}

print_summary() {
  echo ""
  echo -e "${PURPLE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║          INSTALLATION COMPLETE — DEATHLEGIONTEAMLK          ║${NC}"
  echo -e "${PURPLE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${CYAN}${BOLD}PANEL${NC}"
  echo -e "  ${WHITE}URL         :${NC} ${GREEN}https://${PANEL_FQDN}${NC}"
  echo -e "  ${WHITE}Admin User  :${NC} ${YELLOW}${ADMIN_USER}${NC}"
  echo -e "  ${WHITE}Admin Email :${NC} ${YELLOW}${ADMIN_EMAIL}${NC}"
  echo -e "  ${WHITE}Admin Pass  :${NC} ${RED}${BOLD}${ADMIN_PASS}${NC}"
  echo ""
  echo -e "  ${CYAN}${BOLD}DATABASE${NC}"
  echo -e "  ${WHITE}DB Name     :${NC} ${YELLOW}${DB_NAME}${NC}"
  echo -e "  ${WHITE}DB User     :${NC} ${YELLOW}${DB_USER}${NC}"
  echo -e "  ${WHITE}DB Password :${NC} ${RED}${BOLD}${DB_PASS}${NC}"
  echo -e "  ${WHITE}DB Root Pass:${NC} ${RED}${BOLD}${DB_ROOT_PASS}${NC}"
  echo ""
  echo -e "  ${CYAN}${BOLD}WINGS / NODE${NC}"
  echo -e "  ${WHITE}Wings URL   :${NC} ${GREEN}https://${WINGS_FQDN}:${WINGS_PORT}${NC}"
  echo -e "  ${WHITE}SFTP Port   :${NC} ${YELLOW}${WINGS_SFTP_PORT}${NC}"
  echo -e "  ${WHITE}Node ID     :${NC} ${YELLOW}${NODE_ID}${NC}"
  echo -e "  ${WHITE}Location ID :${NC} ${YELLOW}${LOCATION_ID}${NC}"
  echo ""
  echo -e "  ${CYAN}${BOLD}THEME${NC}"
  echo -e "  ${WHITE}Theme       :${NC} ${PURPLE}NookTheme (github.com/Nookure/NookTheme)${NC}"
  echo ""
  echo -e "  ${DIM}All credentials saved to: ${SUMMARY_FILE}${NC}"
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  Wings:  systemctl status wings | journalctl -u wings -f${NC}"
  echo -e "${YELLOW}  Queue:  supervisorctl status pterodactyl-worker:*${NC}"
  echo -e "${YELLOW}  SSL:    certbot certificates${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

main() {
  print_banner
  check_root
  detect_os
  detect_server_ip
  collect_inputs

  configure_zoneid_dns

  install_base_deps
  install_php
  install_composer
  install_nodejs
  install_docker

  issue_ssl "$PANEL_FQDN"
  issue_ssl "$WINGS_FQDN"

  setup_mariadb
  install_nooktheme
  configure_nginx
  configure_supervisor
  configure_cron

  install_wings
  create_location_and_node
  configure_wings_config
  create_allocations
  import_all_eggs
  start_wings

  save_credentials
  print_summary
}

main "$@"
