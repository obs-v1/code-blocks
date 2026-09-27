#!/usr/bin/env bash
#
# install-exporters.sh
#
# Installs Prometheus node_exporter and Percona mongodb_exporter on a Linux
# server and runs them as systemd services.
#
#   node_exporter    -> https://github.com/prometheus/node_exporter
#   mongodb_exporter -> https://github.com/percona/mongodb_exporter
#
# Usage:
#   sudo ./install-exporters.sh                 # install pinned versions
#   sudo NODE_VERSION=latest MONGO_VERSION=latest ./install-exporters.sh
#   sudo NODE_VERSION=1.12.1 MONGO_VERSION=0.51.0 ./install-exporters.sh
#   sudo MONGO_URI="mongodb://user:pass@127.0.0.1:27017" ./install-exporters.sh
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration (override via environment variables)
# ---------------------------------------------------------------------------
NODE_VERSION="${NODE_VERSION:-1.12.1}"        # or "latest"
MONGO_VERSION="${MONGO_VERSION:-0.51.0}"      # or "latest"

NODE_PORT="${NODE_PORT:-9100}"
MONGO_PORT="${MONGO_PORT:-9216}"

# MongoDB server (RoboShop) install settings.
INSTALL_MONGODB="${INSTALL_MONGODB:-yes}"     # set to "no" to skip installing the DB
MONGODB_VERSION="${MONGODB_VERSION:-7.0}"     # MongoDB-org major.minor series
# Bind address written into /etc/mongod.conf. RoboShop uses 0.0.0.0 so app
# servers can connect; keep it 127.0.0.1 if only the local exporter needs it.
MONGO_BIND_IP="${MONGO_BIND_IP:-0.0.0.0}"

# MongoDB connection string used by mongodb_exporter.
# For the RoboShop MongoDB (no auth) the default local connection is fine.
MONGO_URI="${MONGO_URI:-mongodb://127.0.0.1:27017}"

INSTALL_DIR="/usr/local/bin"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo -e "\033[1;32m[+]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }
err()  { echo -e "\033[1;31m[x]\033[0m $*" >&2; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "This script must be run as root (use sudo)."
    exit 1
  fi
}

require_cmd() {
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      err "Required command not found: $c"
      exit 1
    fi
  done
}

# Map uname arch -> the arch string used in release asset names.
detect_arch() {
  local m
  m="$(uname -m)"
  case "$m" in
    x86_64|amd64)  echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l)        echo "armv7" ;;
    *) err "Unsupported architecture: $m"; exit 1 ;;
  esac
}

# Query the GitHub API for the latest release tag (strips the leading "v").
latest_version() {
  local repo="$1"   # e.g. prometheus/node_exporter
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep -oE '"tag_name":[[:space:]]*"[^"]+"' \
    | head -n1 \
    | sed -E 's/.*"v?([^"]+)".*/\1/'
}

# Create a dedicated, non-login system user for a service if it does not exist.
ensure_user() {
  local user="$1"
  if ! id -u "$user" >/dev/null 2>&1; then
    log "Creating system user: $user"
    useradd --no-create-home --shell /usr/sbin/nologin --system "$user"
  fi
}

# ---------------------------------------------------------------------------
# MongoDB server (RoboShop-style install via the official MongoDB yum repo)
#   Ref: https://learndevopsonline.github.io/.../RoboShop-Project-V3/mongodb
# ---------------------------------------------------------------------------
install_mongodb() {
  if [[ "${INSTALL_MONGODB}" != "yes" ]]; then
    warn "Skipping MongoDB install (INSTALL_MONGODB=${INSTALL_MONGODB})"
    return 0
  fi

  if command -v mongod >/dev/null 2>&1; then
    log "MongoDB already installed: $(mongod --version | head -n1)"
  else
    local pkg rhel_major
    # Pick dnf if available, otherwise yum (Amazon Linux / older RHEL).
    pkg="$(command -v dnf || command -v yum)"
    if [[ -z "$pkg" ]]; then
      err "Neither dnf nor yum found. This MongoDB install targets RHEL-family only."
      exit 1
    fi

    # Detect the RHEL major release for the repo path; default to 9 (per doc).
    rhel_major="$(rpm -E %rhel 2>/dev/null || true)"
    [[ "$rhel_major" =~ ^[0-9]+$ ]] || rhel_major=9

    log "Configuring MongoDB ${MONGODB_VERSION} repo (RHEL ${rhel_major})"
    cat > /etc/yum.repos.d/mongo.repo <<EOF
[mongodb-org-${MONGODB_VERSION}]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/${rhel_major}/mongodb-org/${MONGODB_VERSION}/x86_64/
enabled=1
gpgcheck=0
EOF

    log "Installing mongodb-org package"
    "$pkg" install -y mongodb-org
  fi

  # Bind address: RoboShop opens Mongo to 0.0.0.0 so app servers can connect.
  if [[ -f /etc/mongod.conf ]]; then
    log "Setting bindIp to ${MONGO_BIND_IP} in /etc/mongod.conf"
    sed -i -E "s/^([[:space:]]*bindIp:).*/\1 ${MONGO_BIND_IP}/" /etc/mongod.conf
  fi

  log "Enabling and starting mongod"
  systemctl enable mongod
  systemctl restart mongod

  # Give mongod a moment to accept connections before the exporter starts.
  local i
  for i in $(seq 1 15); do
    if systemctl is-active --quiet mongod; then
      log "mongod is active"
      break
    fi
    sleep 1
  done
}

# ---------------------------------------------------------------------------
# node_exporter
# ---------------------------------------------------------------------------
install_node_exporter() {
  local arch tmp url tarball dir
  arch="$(detect_arch)"

  if [[ "${NODE_VERSION}" == "latest" ]]; then
    log "Resolving latest node_exporter version..."
    NODE_VERSION="$(latest_version prometheus/node_exporter)"
  fi
  log "Installing node_exporter v${NODE_VERSION} (${arch})"

  tarball="node_exporter-${NODE_VERSION}.linux-${arch}.tar.gz"
  url="https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/${tarball}"

  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}"' RETURN

  log "Downloading ${url}"
  curl -fSL "$url" -o "${tmp}/${tarball}"
  tar -xzf "${tmp}/${tarball}" -C "$tmp"

  dir="${tmp}/node_exporter-${NODE_VERSION}.linux-${arch}"
  install -m 0755 "${dir}/node_exporter" "${INSTALL_DIR}/node_exporter"

  ensure_user node_exporter

  cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=${INSTALL_DIR}/node_exporter --web.listen-address=:${NODE_PORT}
Restart=on-failure
RestartSec=5
# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

  log "node_exporter installed: $(${INSTALL_DIR}/node_exporter --version 2>&1 | head -n1)"
}

# ---------------------------------------------------------------------------
# mongodb_exporter (Percona)
# ---------------------------------------------------------------------------
install_mongodb_exporter() {
  local arch tmp url tarball dir bin
  arch="$(detect_arch)"

  if [[ "${MONGO_VERSION}" == "latest" ]]; then
    log "Resolving latest mongodb_exporter version..."
    MONGO_VERSION="$(latest_version percona/mongodb_exporter)"
  fi
  log "Installing mongodb_exporter v${MONGO_VERSION} (${arch})"

  tarball="mongodb_exporter-${MONGO_VERSION}.linux-${arch}.tar.gz"
  url="https://github.com/percona/mongodb_exporter/releases/download/v${MONGO_VERSION}/${tarball}"

  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}"' RETURN

  log "Downloading ${url}"
  curl -fSL "$url" -o "${tmp}/${tarball}"
  tar -xzf "${tmp}/${tarball}" -C "$tmp"

  # The Percona tarball extracts to a versioned dir containing the binary.
  bin="$(find "$tmp" -type f -name 'mongodb_exporter' | head -n1)"
  if [[ -z "$bin" ]]; then
    err "mongodb_exporter binary not found in archive"
    exit 1
  fi
  install -m 0755 "$bin" "${INSTALL_DIR}/mongodb_exporter"

  ensure_user mongodb_exporter

  # The MongoDB URI is kept in an EnvironmentFile so credentials are not
  # exposed in the unit file / process list arguments.
  cat > /etc/default/mongodb_exporter <<EOF
MONGODB_URI=${MONGO_URI}
EOF
  chmod 0640 /etc/default/mongodb_exporter
  chown root:mongodb_exporter /etc/default/mongodb_exporter

  cat > /etc/systemd/system/mongodb_exporter.service <<EOF
[Unit]
Description=Percona MongoDB Exporter
Documentation=https://github.com/percona/mongodb_exporter
Wants=network-online.target
After=network-online.target

[Service]
User=mongodb_exporter
Group=mongodb_exporter
Type=simple
EnvironmentFile=/etc/default/mongodb_exporter
ExecStart=${INSTALL_DIR}/mongodb_exporter \\
  --mongodb.uri=\${MONGODB_URI} \\
  --web.listen-address=:${MONGO_PORT} \\
  --collect-all
Restart=on-failure
RestartSec=5
# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

  log "mongodb_exporter installed: $(${INSTALL_DIR}/mongodb_exporter --version 2>&1 | head -n1)"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  require_root
  require_cmd curl tar find sed grep install useradd systemctl

  install_mongodb
  install_node_exporter
  install_mongodb_exporter

  log "Reloading systemd and enabling services"
  systemctl daemon-reload
  systemctl enable --now node_exporter.service
  systemctl enable --now mongodb_exporter.service

  echo
  log "Done."
  [[ "${INSTALL_MONGODB}" == "yes" ]] && \
    echo "  mongodb          -> listening on :27017 (bindIp ${MONGO_BIND_IP})"
  echo "  node_exporter    -> http://<server-ip>:${NODE_PORT}/metrics"
  echo "  mongodb_exporter -> http://<server-ip>:${MONGO_PORT}/metrics"
  echo
  echo "Check status with:"
  echo "  systemctl status mongod node_exporter mongodb_exporter"
  echo "  curl -s localhost:${NODE_PORT}/metrics  | head"
  echo "  curl -s localhost:${MONGO_PORT}/metrics | grep mongodb_up"
}

main "$@"
