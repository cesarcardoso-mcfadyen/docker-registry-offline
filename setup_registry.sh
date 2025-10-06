#!/usr/bin/env bash
set -euo pipefail

# Offline Docker Registry with Local TLS & Cosign - Setup Script
# Usage:
#   ./setup_registry.sh registry.local 10.0.0.5 5000
# Defaults: REG_HOST=registry.local REG_IP=127.0.0.1 REG_PORT=5000
#
# What this script does:
#  1) Create folders: certs, config, data
#  2) Ensure /etc/hosts maps the registry host to the chosen IP (default registry.local -> 127.0.0.1)
#  3) Generate a local CA and server certificate (SAN host/IP)
#  4) Write minimal config.yml
#  5) Write docker-compose.yml
#  6) Start the registry with TLS (no auth)
#  7) Install CA trust for Docker on Linux hosts
#  8) Ensure Cosign is installed (online auto-install or show offline steps)
#  9) Print next steps (push/pull and cosign usage)
#
# Requirements: docker, docker compose plugin, openssl
#
# NOTE: For macOS/Windows Docker Desktop you must import certs/ca.crt into
# the OS trust and copy it to ~/.docker/certs.d/<host:port>/ca.crt manually.

REG_HOST="${1:-registry.local}"
REG_IP="${2:-127.0.0.1}"
REG_PORT="${3:-5000}"
COSIGN_VERSION="${COSIGN_VERSION:-v2.2.4}"  # set via env to override

ROOT_DIR="$(pwd)"
CERTS_DIR="${ROOT_DIR}/certs"
CONFIG_DIR="${ROOT_DIR}/config"
DATA_DIR="${ROOT_DIR}/registry-data"
PORTAINER_DIR="${ROOT_DIR}/portainer-data"

echo "==> Using:"
echo "    REG_HOST=${REG_HOST}"
echo "    REG_IP=${REG_IP}"
echo "    REG_PORT=${REG_PORT}"
echo "    COSIGN_VERSION=${COSIGN_VERSION}"
echo "    ROOT_DIR=${ROOT_DIR}"

############################
# 1) Prepare directories
############################
mkdir -p "${CERTS_DIR}" "${CONFIG_DIR}" "${DATA_DIR}" "${PORTAINER_DIR}"

############################
# 2) Ensure /etc/hosts entry
############################
HOSTS_ENTRY="${REG_IP} ${REG_HOST}"
if awk -v ip="${REG_IP}" -v host="${REG_HOST}" 'BEGIN {found=0} !/^#/ && $1==ip {for (i=2; i<=NF; i++) if ($i==host) found=1} END {exit(found ? 0 : 1)}' /etc/hosts; then
  echo "==> /etc/hosts already maps ${REG_HOST} to ${REG_IP}"
else
  echo "==> Adding ${HOSTS_ENTRY} to /etc/hosts (requires sudo if running as non-root)"
  if [[ -w /etc/hosts ]]; then
    printf '%s\n' "${HOSTS_ENTRY}" >> /etc/hosts
  elif command -v sudo >/dev/null 2>&1; then
    printf '%s\n' "${HOSTS_ENTRY}" | sudo tee -a /etc/hosts >/dev/null
  else
    echo "!! Could not write to /etc/hosts (missing permissions). Please add the following entry manually:"
    echo "   ${HOSTS_ENTRY}"
  fi
fi

############################
# 3) Generate CA & Certs
############################
if [[ ! -f "${CERTS_DIR}/ca.crt" ]]; then
  echo "==> Generating local CA (certs/ca.crt)"
  openssl genrsa -out "${CERTS_DIR}/ca.key" 4096
  openssl req -x509 -new -nodes -key "${CERTS_DIR}/ca.key" -sha256 -days 3650 \
    -subj "/CN=Local Registry CA" -out "${CERTS_DIR}/ca.crt"
else
  echo "==> Found existing CA at certs/ca.crt (skipping CA generation)"
fi

echo "==> Generating server key (certs/domain.key)"
openssl genrsa -out "${CERTS_DIR}/domain.key" 4096

echo "==> Creating SAN config (certs/san.cnf)"
cat > "${CERTS_DIR}/san.cnf" <<EOF
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${REG_HOST}
IP.1  = ${REG_IP}
EOF

echo "==> Generating CSR (certs/domain.csr)"
openssl req -new -key "${CERTS_DIR}/domain.key" -subj "/CN=${REG_HOST}" -out "${CERTS_DIR}/domain.csr"

echo "==> Signing server certificate with local CA (certs/domain.crt)"
openssl x509 -req -in "${CERTS_DIR}/domain.csr" -CA "${CERTS_DIR}/ca.crt" -CAkey "${CERTS_DIR}/ca.key" -CAcreateserial \
  -out "${CERTS_DIR}/domain.crt" -days 1095 -sha256 -extfile "${CERTS_DIR}/san.cnf"

############################
# 4) Write config.yml
############################
if [[ ! -f "${CONFIG_DIR}/config.yml" ]]; then
  echo "==> Writing minimal registry config to config/config.yml"
  cat > "${CONFIG_DIR}/config.yml" <<'YAML'
version: 0.1
log:
  level: info
storage:
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
delete:
  enabled: true
YAML
fi

############################
# 5) Write docker-compose.yaml
############################
echo "==> Writing docker-compose.yaml"
cat > "${ROOT_DIR}/docker-compose.yaml" <<'YAML'
services:
  registry:
    image: registry:2.8.3
    container_name: local-registry
    environment:
      REGISTRY_HTTP_ADDR: 0.0.0.0:5000
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
    volumes:
      - ./registry-data:/var/lib/registry
      - ./certs:/certs:ro
      - ./config/config.yml:/etc/docker/registry/config.yml:ro
    ports:
      - "5000:5000"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "--no-check-certificate", "https://localhost:5000/v2/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    ports:
      - "9000:9000"
      - "8000:8000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./portainer-data:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/api/status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

networks:
  default:
    name: local-registry-network
YAML

############################
# 6) Start registry
############################
echo "==> Starting registry with docker compose"
docker compose up -d

############################
# 7) Trust CA on Linux Docker client
############################
CERTS_D_DIR="/etc/docker/certs.d/${REG_HOST}:${REG_PORT}"
if [[ -d "/etc/docker" ]]; then
  echo "==> Installing CA to Docker trust at ${CERTS_D_DIR} (requires sudo)"
  sudo mkdir -p "${CERTS_D_DIR}"
  sudo cp "${CERTS_DIR}/ca.crt" "${CERTS_D_DIR}/ca.crt" || true

  # Also trust by IP, in case user uses the IP endpoint
  CERTS_D_DIR_IP="/etc/docker/certs.d/${REG_IP}:${REG_PORT}"
  sudo mkdir -p "${CERTS_D_DIR_IP}"
  sudo cp "${CERTS_DIR}/ca.crt" "${CERTS_D_DIR_IP}/ca.crt" || true

  if command -v systemctl >/dev/null 2>&1; then
    echo "==> Restarting Docker daemon"
    sudo systemctl restart docker || true
  fi
else
  echo "==> /etc/docker not found. For Docker Desktop, import certs/ca.crt into system trust and to ~/.docker/certs.d/${REG_HOST}:${REG_PORT}/ca.crt"
fi

############################
# 8) Ensure Cosign available
############################
ensure_cosign() {
  if command -v cosign >/dev/null 2>&1; then
    echo "==> cosign already installed: $(command -v cosign)"
    return 0
  fi

  echo "==> cosign not found, attempting online install (Linux x86_64/arm64)"
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "!! Unsupported arch: ${ARCH}. Install cosign manually."; return 1 ;;
  esac

  COSIGN_URL="https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-${OS}-${ARCH}"
  set +e
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o cosign "${COSIGN_URL}"
  elif command -v wget >/dev/null 2>&1; then
    wget -O cosign "${COSIGN_URL}"
  else
    echo "!! Neither curl nor wget available. Install cosign manually (see README)."
    return 1
  fi
  set -e

  chmod +x cosign
  sudo mv cosign /usr/local/bin/cosign || true

  if ! command -v cosign >/dev/null 2>&1; then
    echo "!! Failed to install cosign automatically. Please install manually (see README)."
    return 1
  fi
  echo "==> cosign installed: $(command -v cosign)"
}

ensure_cosign || true

############################
# 9) Print next steps
############################
cat <<EOF

=======================================
✅ Registry is up at: https://${REG_HOST}:${REG_PORT}/v2/
✅ CA installed for Docker (Linux path: /etc/docker/certs.d/${REG_HOST}:${REG_PORT}/ca.crt)

Quick test (hello-world sample):
  curl -k https://${REG_HOST}:${REG_PORT}/v2/_catalog
  
  cd hello-world-image
  docker build -t ${REG_HOST}:${REG_PORT}/hello-world:latest .
  docker push ${REG_HOST}:${REG_PORT}/hello-world:latest
  
  curl -k https://${REG_HOST}:${REG_PORT}/v2/_catalog

  docker image rm ${REG_HOST}:${REG_PORT}/hello-world:latest
  docker pull ${REG_HOST}:${REG_PORT}/hello-world:latest
  docker run --rm -d -p 8080:80 --name hello-world ${REG_HOST}:${REG_PORT}/hello-world:latest
  docker stop hello-world
  cd ..

Cosign - optional (works offline; signatures stored in registry):
  export COSIGN_PASSWORD='changeme'
  cosign generate-key-pair --output-key cosign.key --output-pub cosign.pub
  cosign sign --key cosign.key --tlog-upload=false ${REG_HOST}:${REG_PORT}/hello-world:latest
  cosign verify --key cosign.pub ${REG_HOST}:${REG_PORT}/hello-world:latest

If you see x509 SAN errors, ensure you push/pull using the same name:
  ${REG_HOST}:${REG_PORT}  or  ${REG_IP}:${REG_PORT}
and place CA at /etc/docker/certs.d/<host:port>/ca.crt accordingly.

Done.
=======================================
EOF
