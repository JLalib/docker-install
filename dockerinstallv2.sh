#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ========= CONFIG =========
# Cambia esto si quieres añadir otro usuario al grupo docker.
TARGET_USER="${SUDO_USER:-${USER:-}}"

echo "[1/7] Actualizando e instalando prerequisitos..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release sudo

echo "[2/7] Añadiendo repo oficial de Docker..."
# Evita repetir si ya existe
if ! [ -f /etc/apt/keyrings/docker.gpg ]; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

CODENAME="$(. /etc/os-release; echo "$VERSION_CODENAME")"
if ! grep -qs "^deb .*download.docker.com" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
    ${CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

echo "[3/7] Instalando Docker Engine + Compose plugin..."
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[4/7] Habilitando y arrancando Docker..."
sudo systemctl enable --now docker
sleep 2
sudo docker info >/dev/null

echo "[5/7] Verificando Docker Compose (v2)..."
docker compose version || true

echo "[6/7] Añadiendo usuario al grupo docker (si procede)..."
if [ -n "${TARGET_USER}" ] && id -u "${TARGET_USER}" >/dev/null 2>&1; then
  sudo usermod -aG docker "${TARGET_USER}"
  echo "   -> Usuario '${TARGET_USER}' añadido a 'docker' (relogin requerido)."
else
  echo "   -> Aviso: usuario destino no válido; omito usermod."
fi

echo "[7/7] Desplegando Portainer CE (puerto 9000)..."
# Idempotente: si ya existe, solo lo levanta
if ! docker ps -a --format '{{.Names}}' | grep -qx "portainer"; then
  docker run -d \
    -p 9000:9000 \
    --name=portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
else
  docker start portainer >/dev/null || true
fi

echo
echo "✅ Listo. Comprueba:"
echo "   - Docker:        docker info"
echo "   - Compose v2:    docker compose version"
echo "   - Portainer:     http://<IP-del-servidor>:9000"
echo
echo "ℹ️ Nota: para usar 'docker' sin sudo, cierra y vuelve a abrir sesión (o 'newgrp docker')."
