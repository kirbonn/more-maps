#!/bin/bash

set -e

NUM_CONTAINERS=10
CONTAINER_PREFIX="student"
USERNAME="student"
PASSWORD="password123"
BASE_WEB_PORT=3000
BASE_SSH_PORT=2220
OUTPUT_FILE="student_web_links.txt"
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "[+] Ensuring LXD is initialized..."

if ! lxc network list | grep -q lxdbr0; then
    echo "[+] Running lxd init --auto"
    sudo lxd init --auto
fi

if ! lxc storage list | grep -q default; then
    echo "[+] Creating default storage pool..."
    lxc storage create default dir
fi

if ! lxc profile show default | grep -q root; then
    echo "[+] Adding root disk to default profile..."
    lxc profile device add default root disk path=/ pool=default
fi

echo "[+] Creating containers and Wetty access..."

> "$OUTPUT_FILE"

for i in $(seq 1 $NUM_CONTAINERS); do
    NAME="${CONTAINER_PREFIX}${i}"
    SSH_PORT=$((BASE_SSH_PORT + i))
    WEB_PORT=$((BASE_WEB_PORT + i))

    echo "[+] Launching container: $NAME"
    lxc launch ubuntu:22.04 $NAME
    sleep 10

    echo "[+] Configuring container: $NAME"
    lxc exec $NAME -- bash -c "
        apt update && apt install -y openssh-server sudo
        adduser --disabled-password --gecos '' $USERNAME
        echo '$USERNAME:$PASSWORD' | chpasswd
        usermod -aG sudo $USERNAME
        systemctl enable ssh && systemctl restart ssh
    "

    echo "[+] Setting up SSH port forward: $SSH_PORT"
    lxc config device add $NAME sshproxy proxy listen=tcp:127.0.0.1:$SSH_PORT connect=tcp:127.0.0.1:22

    echo "[+] Starting Wetty on port $WEB_PORT for $NAME"
    docker run -d \
        --name wetty-$NAME \
        -p $WEB_PORT:3000 \
        --restart always \
        wettyoss/wetty \
        --ssh-host=127.0.0.1 \
        --ssh-port=$SSH_PORT \
        --ssh-user=$USERNAME

    echo "$NAME => http://$SERVER_IP:$WEB_PORT (login: $USERNAME / $PASSWORD)" >> "$OUTPUT_FILE"
done

echo "[✓] All student terminals ready! Links saved in $OUTPUT_FILE"
