#!/bin/sh
# Standalone launcher: only Docker Engine + Compose are needed, no repository.
# Generated from compose.yaml and scripts/wargame.sh.in; edit those sources.
set -eu
export WARGAME_REGISTRY="${WARGAME_REGISTRY:-ghcr.io/labudzinski}"
export WARGAME_VERSION="${WARGAME_VERSION:-1.2.1}"

action=start
local_images=false
for argument in "$@"; do
    case "$argument" in
        start|restart|stop|status|logs|pull) action=$argument ;;
        --local) local_images=true ;;
        -h|--help)
            echo 'Użycie: sh wargame.sh [start|restart|stop|status|logs|pull] [--local]'
            echo 'Domyślnie pobiera obrazy z GHCR i zaczyna nową grę. --local używa obrazów już dostępnych.'
            exit 0 ;;
        *) echo "Nieznany argument: $argument" >&2; exit 64 ;;
    esac
done

project=${WARGAME_PROJECT:-wargame-level-1}
case "$project" in
    ''|[!a-z0-9]*|*[!a-z0-9_-]*) echo 'Niepoprawna nazwa WARGAME_PROJECT.' >&2; exit 64 ;;
esac
command -v docker >/dev/null 2>&1 || { echo 'Zainstaluj Docker Desktop albo Docker Engine z Compose.' >&2; exit 69; }
docker compose version >/dev/null 2>&1 || { echo 'Potrzebny jest Docker Compose v2 lub nowszy.' >&2; exit 69; }
docker info >/dev/null 2>&1 || { echo 'Uruchom Docker i sprawdź dostęp do jego silnika.' >&2; exit 69; }

compose() {
    docker compose --project-name "$project" -f - "$@" <<'WARGAME_COMPOSE'
x-isolation: &isolation
  read_only: true
  cap_drop: [ALL]
  security_opt: [no-new-privileges:true]
  init: true
  restart: unless-stopped
  pids_limit: 96
  mem_limit: 192m
  cpus: 0.75
  ulimits:
    nofile:
      soft: 1024
      hard: 1024
    core: 0
    fsize:
      soft: 131072
      hard: 131072
  networks: [las]
  logging:
    driver: json-file
    options:
      max-size: 5m
      max-file: '3'

services:
  babcia:
    <<: *isolation
    image: ${WARGAME_REGISTRY:-ghcr.io/labudzinski}/wargame-level-1-web:${WARGAME_VERSION:-1.2.1}
    user: '10001:10000'
    command: [web]
    tmpfs:
      - /tmp:rw,noexec,nosuid,nodev,size=16m,mode=1777
    volumes:
      - fasada:/srv/babcia:ro
      - koszyk:/srv/koszyk:ro
    depends_on:
      lesniczy:
        condition: service_healthy
    healthcheck:
      test: [CMD, python, -c, "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2).read()"]
      interval: 15s
      timeout: 3s
      retries: 3
      start_period: 10s
  lesniczy:
    <<: *isolation
    image: ${WARGAME_REGISTRY:-ghcr.io/labudzinski}/wargame-level-1-ssh:${WARGAME_VERSION:-1.2.1}
    user: '10002:10000'
    command: [ssh]
    tmpfs:
      - /tmp:rw,noexec,nosuid,nodev,size=32m,mode=1777
      - /run/wargame:rw,noexec,nosuid,nodev,size=4m,uid=10002,gid=10000,mode=0700
    volumes:
      - fasada:/srv/babcia:rw
      - koszyk:/srv/koszyk:rw
    healthcheck:
      test: [CMD, python, -c, "import socket; s=socket.create_connection(('127.0.0.1',2222),2); assert s.recv(100).startswith(b'SSH-'); s.close()"]
      interval: 15s
      timeout: 3s
      retries: 3
      start_period: 10s

  brama:
    <<: *isolation
    image: ${WARGAME_REGISTRY:-ghcr.io/labudzinski}/wargame-level-1-gateway:${WARGAME_VERSION:-1.2.1}
    user: '10003:10003'
    command: [gate]
    networks: [las, wejscie]
    tmpfs:
      - /tmp:rw,noexec,nosuid,nodev,size=8m,mode=1777
    ports:
      - '127.0.0.1:${WEB_PORT:-8080}:8080'
      - '127.0.0.1::2222'
    depends_on:
      babcia:
        condition: service_healthy
      lesniczy:
        condition: service_healthy
    healthcheck:
      test: [CMD, python, -c, "import socket; s=socket.create_connection(('127.0.0.1',2222),2); assert s.recv(100).startswith(b'SSH-'); s.close()"]
      interval: 15s
      timeout: 3s
      retries: 3
      start_period: 10s

volumes:
  fasada:
  koszyk:
    driver: local
    driver_opts:
      type: tmpfs
      device: tmpfs
      o: size=2m,nr_inodes=128,nosuid,nodev,noexec,uid=10002,gid=10000,mode=0755
networks:
  las:
    internal: true
  wejscie:
WARGAME_COMPOSE
}

show_status() {
    web=$(compose port brama 8080) || return 1
    printf 'http://%s\n' "$web"
}

case "$action" in
    start|restart)
        if [ "$local_images" = false ]; then
            startup_output=$(compose pull 2>&1) || {
                printf '%s\n' "$startup_output" >&2
                echo 'Nie udało się pobrać obrazów. Sprawdź połączenie, wersję i dostępność pakietów GHCR.' >&2
                exit 69
            }
        fi
        startup_output=$(compose up -d --no-build --pull never --force-recreate --remove-orphans --wait --wait-timeout 90 2>&1) || {
            status=$?
            printf '%s\n' "$startup_output" >&2
            exit "$status"
        }
        show_status
        ;;
    stop) compose down --volumes --remove-orphans ;;
    status) show_status ;;
    logs) compose logs --tail 100 -f ;;
    pull) compose pull ;;
esac
