#!/bin/sh
# Standalone launcher: only Docker Engine + Compose are needed, no repository.
# Generated from level*/compose.yaml and scripts/wargame.sh.in; edit those sources.
set -eu
export WARGAME_REGISTRY="${WARGAME_REGISTRY:-ghcr.io/labudzinski}"
export WARGAME_VERSION="${WARGAME_VERSION:-1.2.1}"
export WARGAME_LEVEL2_VERSION="${WARGAME_LEVEL2_VERSION:-1.0.0}"

action=start
level=1
local_images=false
for argument in "$@"; do
    case "$argument" in
        start|restart|stop|status|logs|pull) action=$argument ;;
        --local) local_images=true ;;
        --level=1|--level=2) level=${argument#--level=} ;;
        -h|--help)
            echo 'Użycie: sh wargame.sh [start|restart|stop|status|logs|pull] [--level=1|--level=2] [--local]'
            echo 'Domyślnie pobiera obrazy z GHCR i zaczyna nową grę. --local używa obrazów już dostępnych.'
            exit 0 ;;
        *) echo "Nieznany argument: $argument" >&2; exit 64 ;;
    esac
done

project=${WARGAME_PROJECT:-wargame-level-$level}
case "$project" in
    ''|[!a-z0-9]*|*[!a-z0-9_-]*) echo 'Niepoprawna nazwa WARGAME_PROJECT.' >&2; exit 64 ;;
esac
command -v docker >/dev/null 2>&1 || { echo 'Zainstaluj Docker Desktop albo Docker Engine z Compose.' >&2; exit 69; }
docker compose version >/dev/null 2>&1 || { echo 'Potrzebny jest Docker Compose v2 lub nowszy.' >&2; exit 69; }
docker info >/dev/null 2>&1 || { echo 'Uruchom Docker i sprawdź dostęp do jego silnika.' >&2; exit 69; }

compose() {
    if [ "$level" = 2 ]; then
        docker compose --project-name "$project" -f - "$@" <<'WARGAME_COMPOSE_LEVEL2'
x-isolation: &isolation
  read_only: true
  cap_drop: [ALL]
  security_opt: [no-new-privileges:true]
  init: true
  restart: unless-stopped
  pids_limit: 128
  mem_limit: 256m
  cpus: 0.75
  ulimits:
    nofile: {soft: 1024, hard: 1024}
    core: 0
    fsize: {soft: 1048576, hard: 1048576}
  networks: [las]
  logging:
    driver: json-file
    options: {max-size: 5m, max-file: '3'}

services:
  piekarnia:
    <<: *isolation
    image: ${WARGAME_REGISTRY:-ghcr.io/labudzinski}/wargame-level-2-web:${WARGAME_LEVEL2_VERSION:-1.0.0}
    user: '20001:20000'
    command: [web]
    tmpfs:
      - /tmp:rw,noexec,nosuid,nodev,size=16m,mode=1777
      - /run/piernikarnia:rw,noexec,nosuid,nodev,size=12m,uid=20001,gid=20000,mode=0700
    volumes: [pracownia:/srv/pracownia:rw]
    healthcheck:
      test: [CMD, python, -c, "import urllib.request; [urllib.request.urlopen('http://127.0.0.1:'+str(p)+'/healthz',timeout=2).read() for p in (8080,8081)]"]
      interval: 5s
      timeout: 4s
      retries: 12
      start_period: 10s
  strych:
    <<: *isolation
    image: ${WARGAME_REGISTRY:-ghcr.io/labudzinski}/wargame-level-2-ssh:${WARGAME_LEVEL2_VERSION:-1.0.0}
    user: '20002:20000'
    command: [ssh]
    tmpfs:
      - /tmp:rw,noexec,nosuid,nodev,size=32m,mode=1777
      - /run/strych:rw,noexec,nosuid,nodev,size=4m,uid=20002,gid=20000,mode=0700
    volumes: [pracownia:/srv/pracownia:ro]
    depends_on:
      piekarnia: {condition: service_healthy}
    healthcheck:
      test: [CMD, python, -c, "import socket; s=socket.create_connection(('127.0.0.1',2222),2); assert s.recv(100).startswith(b'SSH-'); s.close()"]
      interval: 5s
      timeout: 3s
      retries: 12
      start_period: 10s
  brama:
    <<: *isolation
    image: ${WARGAME_REGISTRY:-ghcr.io/labudzinski}/wargame-level-2-gateway:${WARGAME_LEVEL2_VERSION:-1.0.0}
    user: '20003:20003'
    command: [gate]
    networks: [las, wejscie]
    tmpfs: ['/tmp:rw,noexec,nosuid,nodev,size=8m,mode=1777']
    ports: ['127.0.0.1:${WEB_PORT:-0}:8080', '127.0.0.1::2222']
    depends_on:
      piekarnia: {condition: service_healthy}
      strych: {condition: service_healthy}
    healthcheck:
      test: [CMD, python, -c, "import socket; s=socket.create_connection(('127.0.0.1',2222),2); assert s.recv(100).startswith(b'SSH-'); s.close()"]
      interval: 5s
      timeout: 3s
      retries: 6

volumes:
  pracownia:
    driver: local
    driver_opts:
      type: tmpfs
      device: tmpfs
      o: size=4m,nr_inodes=512,nosuid,nodev,noexec,uid=20001,gid=20000,mode=0750
networks:
  las: {internal: true}
  wejscie:
WARGAME_COMPOSE_LEVEL2
    else
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
      - '127.0.0.1:${WEB_PORT:-0}:8080'
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
    fi
}

show_status() {
    web=$(compose port brama 8080) || return 1
    if [ "$level" = 2 ]; then
        ssh_endpoint=$(compose port brama 2222) || return 1
        host_key=$(compose exec -T strych ssh-keygen -lf /run/strych/host_ed25519.pub) || return 1
        fingerprint=$(printf '%s\n' "$host_key" | awk '{print $2}')
        compose exec -T piekarnia python /opt/piernikarnia/app/register_endpoint.py "${ssh_endpoint##*:}" "$fingerprint" || return 1
    fi
    printf 'http://wargame-%s.localhost:%s\n' "$level" "${web##*:}"
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
