#!/bin/bash

set -e

export IMAGE_NAME=registry.gitlab.com/trapper-project/trapper-frontend

COLOR_RED_BRIGHT='\033[1;31m'
COLOR_GREEN_BRIGHT='\033[1;32m'
COLOR_BLUE_BRIGHT='\033[1;34m'
NO_COLOR='\033[0m' # No Color

# Defaults (can be overridden by .env)
export BUILD_IMAGES="${BUILD_IMAGES:-0}"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-trapper-frontend}"
export APP_NAME="${APP_NAME:-trapper-frontend-cs}"
export DOCKERFILE="${DOCKERFILE:-docker/Dockerfile}"
export TRAPPER_BACKEND_URL="${TRAPPER_BACKEND_URL:-https://wildintel-trap.uhu.es}"
export USER="${USER:-$UID}"
export INSTANCES="${INSTANCES:-3}"
export CADDY_LOG_LEVEL="${CADDY_LOG_LEVEL:-INFO}"
export CADDY_PROFILE="${CADDY_PROFILE:-prod}" # prod | debug
export TRAEFIK_NETWORK="${TRAEFIK_NETWORK:-wildintel-proxy}"

CODE_DIR="$(pwd)"
ACTIVE_BRANCH=main

# Global variables
fragments=()
compose_files=()

# Utility functions

load_dotenv() {
  if [ -f .env ]; then
    print_info "Loading environment variables from .env file..."
    set -a
    . ./.env
    set +a
  else
    print_info "No .env file, skipping..."
  fi
}

print_err() {
  echo -e "${COLOR_RED_BRIGHT}[ERROR]${NO_COLOR} $1"
  exit 1
}

print_ok() {
  echo -e "${COLOR_GREEN_BRIGHT}[OK]${NO_COLOR} $1"
}

print_info() {
  echo -e "${COLOR_BLUE_BRIGHT}[INFO]${NO_COLOR} $1"
}

print_warn() {
  echo -e "${COLOR_RED_BRIGHT}[WARN]${NO_COLOR} $1"
}

check_required_env_var() {
  local var="$1"
  if [ -n "${!var}" ]; then
    print_ok "$var set"
  else
    print_err "Required environment variable $var not present, aborting"
  fi
}

# Deployment functions

build_backend() {
  print_info "Building trapper citizen science image"
  docker run --rm -v .:/app node /bin/bash -c "cd /app && npm install && npm run build && chown -R $USER dist"
  docker build . -f "${DOCKERFILE}" --build-arg="APP_NAME=${APP_NAME}" -t "${IMAGE_NAME}:${IMAGE_TAG_WEB}"
}

build_images() {
  build_backend
}

pull_images() {
  print_info "Pulling image ${IMAGE_NAME}:${IMAGE_TAG_WEB}"
  docker pull "${IMAGE_NAME}:${IMAGE_TAG_WEB}"
  docker compose "${compose_files[@]}" pull
}

export_image_tags() {
  if [ "$BUILD_IMAGES" = "1" ]; then
    ACTIVE_BRANCH=local
  fi
  export IMAGE_TAG_WEB="$ACTIVE_BRANCH"
  print_info "Using IMAGE_TAG_WEB=${IMAGE_TAG_WEB}"
}

obtain_images() {
  if [ "$BUILD_IMAGES" = "1" ]; then
    print_info "BUILD_IMAGES=1, building images"
    build_images
  else
    print_info "BUILD_IMAGES=0, pulling images"
    pull_images
  fi
}

configure_caddy_profile() {
  if [ "$CADDY_PROFILE" = "prod" ] || [ "$CADDY_PROFILE" = "debug" ]; then
    print_info "Using Caddy profile: ${CADDY_PROFILE}"
    fragments+=("caddy-${CADDY_PROFILE}")
  else
    print_err "Invalid CADDY_PROFILE='${CADDY_PROFILE}'. Allowed values: prod | debug"
  fi
}

check_required_env_variables() {
  local required_vars=("TRAPPER_BACKEND_URL")

  print_info "Checking basic configuration"
  for var in "${required_vars[@]}"; do
    check_required_env_var "$var"
  done
}

aggregate_compose_files() {
  for fragment in "${fragments[@]}"; do
    compose_files+=("-f" "docker/docker-compose.${fragment}.yml")
  done
}

prepare_config() {
  fragments=()
  compose_files=()

  load_dotenv
  check_required_env_variables
  export_image_tags

  fragments+=("base" "traefik")
  configure_caddy_profile
  aggregate_compose_files
}

start() {
  print_info "Compose files: ${compose_files[*]}"
  docker compose "${compose_files[@]}" up --scale "app=${INSTANCES}" --remove-orphans
}

start_detached() {
  print_info "Compose files: ${compose_files[*]}"
  docker compose "${compose_files[@]}" up --scale "app=${INSTANCES}" -d --remove-orphans
}

stop() {
  docker compose "${compose_files[@]}" down --remove-orphans
}

logs() {
  docker compose "${compose_files[@]}" logs -f
}

docker_shell() {
  print_info "Entering app container shell"
  docker compose "${compose_files[@]}" run --rm app sh
}

main() {
  local cmd="$1"
  prepare_config

  if [ "$cmd" = "start" ]; then
    obtain_images
    start_detached
  elif [ "$cmd" = "start-i" ]; then
    obtain_images
    start
  elif [ "$cmd" = "stop" ]; then
    stop
  elif [ "$cmd" = "logs" ]; then
    logs
  elif [ "$cmd" = "shell" ]; then
    docker_shell
  else
    print_err "Invalid command: ${cmd}"
  fi
}

main "$1"
