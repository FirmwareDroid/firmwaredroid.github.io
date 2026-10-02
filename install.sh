#!/usr/bin/env bash
# ==============================================================================
# FirmwareDroid (FMD) Installer & Environment Verification Script
# https://firmwaredroid.github.io
#
# Usage:
#   curl -fsSL https://firmwaredroid.github.io/install.sh | bash
#
# Non-interactive / unattended flags:
#   curl -fsSL https://firmwaredroid.github.io/install.sh | bash -s -- --yes
# ==============================================================================

set -eo pipefail

REPO_URL="https://github.com/FirmwareDroid/FirmwareDroid.git"
DEFAULT_TARGET_DIR="FirmwareDroid"
DOMAIN_NAME="fmd.localhost"
MIN_FREE_DISK_GB=15
COMPOSE_FILE="docker-compose-release.yml"

# Colors & Formatting
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  BOLD="$(tput bold 2>/dev/null || true)"
  RESET="$(tput sgr0 2>/dev/null || true)"
  RED="$(tput setaf 1 2>/dev/null || true)"
  GREEN="$(tput setaf 2 2>/dev/null || true)"
  YELLOW="$(tput setaf 3 2>/dev/null || true)"
  BLUE="$(tput setaf 4 2>/dev/null || true)"
  CYAN="$(tput setaf 6 2>/dev/null || true)"
else
  BOLD=""
  RESET=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  CYAN=""
fi

log_info()    { echo -e "${CYAN}==>${RESET} ${BOLD}$*${RESET}"; }
log_step()    { echo -e "  ${BLUE}•${RESET} $*"; }
log_ok()      { echo -e "  ${GREEN}✔${RESET} $*"; }
log_warn()    { echo -e "  ${YELLOW}⚠${RESET} ${YELLOW}$*${RESET}"; }
log_err()     { echo -e "  ${RED}✖${RESET} ${RED}$*${RESET}" >&2; }

print_banner() {
  cat << "EOF"
  _____ _                                    _____            _     _ 
 |  ___(_)_ __ _ ____      ____ _ _ __ ___  |  _  \ _ __ ___ (_) __| |
 | |_  | | '__| '_ \ \ /\ / / _` | '__/ _ \ | | | | '__/ _ \| |/ _` |
 |  _| | | |  | | | \ V  V / (_| | | |  __/ | |_| | | | (_) | | (_| |
 |_|   |_|_|  |_| |_|\_/\_/ \__,_|_|  \___| |____/|_|  \___/|_|\__,_|
                 Automated Setup & Preflight Check
EOF
  echo
}

# Parse options
AUTO_CONFIRM=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes|--non-interactive)
      AUTO_CONFIRM=true
      ;;
    -h|--help)
      echo "Usage: curl -fsSL https://firmwaredroid.github.io/install.sh | bash [-s -- [options]]"
      echo
      echo "Options:"
      echo "  -y, --yes          Run without interactive confirmation prompts"
      echo "  -h, --help         Show this help message"
      exit 0
      ;;
  esac
done

print_banner

FAILED_CHECKS=0
WARNING_CHECKS=0

# ------------------------------------------------------------------------------
# 1. Operating System & Architecture Check
# ------------------------------------------------------------------------------
log_info "1. Checking System Architecture & OS..."

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Linux*)
    log_ok "Operating System: Linux ($ARCH)"
    ;;
  Darwin*)
    log_ok "Operating System: macOS ($ARCH)"
    if [[ "$ARCH" == "arm64" ]]; then
      log_warn "Apple Silicon (M1/M2/M3/M4) detected. FirmwareDroid images use linux/amd64 emulation via Rosetta."
      log_warn "Ensure Docker Desktop has 'Use Rosetta for x86/amd64 emulation' enabled for optimal performance."
    fi
    ;;
  CYGWIN*|MINGW*|MSYS*)
    log_err "Native Windows shell detected. FirmwareDroid requires Docker on Linux or WSL2."
    log_err "Please run this installer inside Ubuntu on WSL2: https://learn.microsoft.com/en-us/windows/wsl/install"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    ;;
  *)
    log_warn "Unrecognized operating system: $OS. Setup will proceed, but compatibility is not guaranteed."
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
    ;;
esac

# ------------------------------------------------------------------------------
# 2. Required Command Line Tools (Git, Curl)
# ------------------------------------------------------------------------------
log_info "2. Checking Required CLI Utilities..."

if command -v git >/dev/null 2>&1; then
  GIT_VER="$(git --version | head -n 1)"
  log_ok "Git installed ($GIT_VER)"
else
  log_err "Git is not installed. Please install git (e.g., 'apt install git' or 'brew install git')."
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

if command -v curl >/dev/null 2>&1; then
  log_ok "cURL installed"
else
  log_err "cURL is not installed."
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# ------------------------------------------------------------------------------
# 3. Docker Engine & Docker Compose Check
# ------------------------------------------------------------------------------
log_info "3. Checking Docker & Compose V2..."

if ! command -v docker >/dev/null 2>&1; then
  log_err "Docker is not installed or not in PATH."
  log_err "Please install Docker Desktop or Docker Engine: https://docs.docker.com/get-docker/"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
  DOCKER_VER="$(docker --version | head -n 1)"
  log_ok "Docker CLI available ($DOCKER_VER)"

  # Verify daemon is running
  if ! docker info >/dev/null 2>&1; then
    log_err "Docker daemon is not running or the current user does not have permission to access the socket."
    log_err "Make sure Docker Desktop / dockerd is active, and your user is in the 'docker' group if on Linux."
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  else
    log_ok "Docker daemon is running and responsive"
  fi

  # Verify Compose v2
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_VER="$(docker compose version | head -n 1)"
    log_ok "Docker Compose v2 plugin available ($COMPOSE_VER)"
  elif command -v docker-compose >/dev/null 2>&1; then
    log_warn "Legacy 'docker-compose' found, but Compose V2 ('docker compose') is strongly recommended."
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
  else
    log_err "Docker Compose is missing. Compose V2 plugin is required."
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
fi

# ------------------------------------------------------------------------------
# 4. Port Availability Checks
# ------------------------------------------------------------------------------
log_info "4. Checking Required Host Ports (80, 443, 27017, 7474)..."

check_port_free() {
  local port="$1"
  local desc="$2"
  local in_use=false

  if command -v lsof >/dev/null 2>&1; then
    if lsof -iTCP:"$port" -sTCP:LISTEN -P -n >/dev/null 2>&1; then
      in_use=true
    fi
  elif command -v ss >/dev/null 2>&1; then
    if ss -tlpn "sport = :$port" 2>/dev/null | grep -q "$port"; then
      in_use=true
    fi
  elif command -v netstat >/dev/null 2>&1; then
    if netstat -tlpn 2>/dev/null | grep -q ":$port "; then
      in_use=true
    fi
  fi

  if [[ "$in_use" == true ]]; then
    log_warn "Port $port ($desc) is already in use by another process on this host."
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
  else
    log_ok "Port $port ($desc) is available"
  fi
}

check_port_free 80 "HTTP Nginx Proxy"
check_port_free 443 "HTTPS Nginx / GraphQL / Web UI"
check_port_free 27017 "MongoDB"
check_port_free 7474 "Neo4j Browser"

# ------------------------------------------------------------------------------
# 5. Disk Space Verification
# ------------------------------------------------------------------------------
log_info "5. Checking Available Disk Space..."

AVAIL_KB=$(df -k . | awk 'NR==2 {print $4}')
if [[ -n "$AVAIL_KB" ]]; then
  AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
  if (( AVAIL_GB < MIN_FREE_DISK_GB )); then
    log_warn "Available disk space is only ~${AVAIL_GB} GB (recommended: ≥ ${MIN_FREE_DISK_GB} GB for Docker images and firmware unpacking)."
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
  else
    log_ok "Available disk space: ~${AVAIL_GB} GB (meets recommendation of ≥ ${MIN_FREE_DISK_GB} GB)"
  fi
else
  log_ok "Could not determine exact disk space; proceeding."
fi

# ------------------------------------------------------------------------------
# Preflight Result Evaluation
# ------------------------------------------------------------------------------
echo
if (( FAILED_CHECKS > 0 )); then
  log_err "Preflight check failed with $FAILED_CHECKS critical error(s)."
  log_err "Please resolve the above issues and run this script again."
  exit 1
fi

if (( WARNING_CHECKS > 0 )); then
  log_warn "Preflight completed with $WARNING_CHECKS warning(s). Installation can still proceed."
else
  log_ok "All preflight requirements verified successfully!"
fi

echo
if [[ "$AUTO_CONFIRM" != true ]]; then
  echo -n "${BOLD}Would you like to download and start FirmwareDroid now in './$DEFAULT_TARGET_DIR'? [Y/n]: ${RESET}"
  read -r response
  case "$response" in
    [nN][oO]|[nN])
      echo "Aborted by user. You can start FirmwareDroid anytime using:"
      echo "  git clone $REPO_URL && cd $DEFAULT_TARGET_DIR && docker compose -f $COMPOSE_FILE up -d"
      exit 0
      ;;
    *)
      # Continue
      ;;
  esac
fi

# ------------------------------------------------------------------------------
# Clone Repository
# ------------------------------------------------------------------------------
echo
log_info "Downloading FirmwareDroid repository..."

if [[ -d "$DEFAULT_TARGET_DIR" ]]; then
  log_warn "Directory './$DEFAULT_TARGET_DIR' already exists."
  cd "$DEFAULT_TARGET_DIR"
  if [[ -d ".git" ]]; then
    log_step "Fetching latest updates..."
    git pull origin main || true
  fi
else
  git clone --depth 1 "$REPO_URL" "$DEFAULT_TARGET_DIR"
  cd "$DEFAULT_TARGET_DIR"
fi

# ------------------------------------------------------------------------------
# Launch Docker Compose Stack
# ------------------------------------------------------------------------------
echo
log_info "Launching FirmwareDroid stack with Docker Compose..."
log_step "Using image bundle from GitHub Container Registry ($COMPOSE_FILE)..."

docker compose -f "$COMPOSE_FILE" up -d

echo
log_info "Waiting for initialization container ('fmd-init') to generate secrets & TLS certificates..."

# Wait for init container to finish up to 60s
RETRIES=0
MAX_RETRIES=30
INIT_DONE=false

while (( RETRIES < MAX_RETRIES )); do
  STATUS=$(docker compose -f "$COMPOSE_FILE" ps -a --format json 2>/dev/null | grep -i '"init"' || true)
  if docker compose -f "$COMPOSE_FILE" ps -a init 2>/dev/null | grep -q "Exited (0)"; then
    INIT_DONE=true
    break
  fi
  sleep 2
  RETRIES=$((RETRIES + 1))
done

if [[ "$INIT_DONE" == true ]]; then
  log_ok "Bootstrap initialization completed successfully!"
else
  log_warn "Initialization container is still working or completed. Continuing..."
fi

# ------------------------------------------------------------------------------
# Display Credentials & Next Steps
# ------------------------------------------------------------------------------
echo
echo "=========================================================================="
echo -e "${GREEN}${BOLD}   FirmwareDroid (FMD) is starting up!${RESET}"
echo "=========================================================================="
echo
echo -e "Web Client & API:   ${CYAN}https://${DOMAIN_NAME}/${RESET}"
echo -e "GraphQL Explorer:   ${CYAN}https://${DOMAIN_NAME}/graphql/${RESET}"
echo -e "Django Admin:       ${CYAN}https://${DOMAIN_NAME}/admin/${RESET}"
echo -e "Queue Manager:      ${CYAN}https://${DOMAIN_NAME}/django-rq/${RESET}"
echo -e "Neo4j Browser:      ${CYAN}http://localhost:7474/${RESET}"
echo
echo -e "${BOLD}Administrator Credentials:${RESET}"
echo "--------------------------------------------------------------------------"
if docker compose -f "$COMPOSE_FILE" cp init:/config/secrets/generated-secrets.txt . 2>/dev/null && [[ -f "generated-secrets.txt" ]]; then
  cat generated-secrets.txt
  echo "--------------------------------------------------------------------------"
  echo -e "${YELLOW}Credentials saved locally to:${RESET} ./$DEFAULT_TARGET_DIR/generated-secrets.txt"
else
  echo "Credentials can be retrieved anytime using:"
  echo "  docker compose -f $COMPOSE_FILE cp init:/config/secrets/generated-secrets.txt ."
  echo "  cat generated-secrets.txt"
  echo "--------------------------------------------------------------------------"
fi

echo
echo -e "${BOLD}Useful Commands:${RESET}"
echo "  View logs:          docker compose -f $COMPOSE_FILE logs -f"
echo "  Check services:     docker compose -f $COMPOSE_FILE ps"
echo "  Stop stack:         docker compose -f $COMPOSE_FILE down"
echo
echo -e "${GREEN}Explore the full documentation at:${RESET} https://firmwaredroid.github.io/documentation/"
echo "=========================================================================="
