#!/bin/bash

set -e

# Config
NUM_CONTAINERS=10
CONTAINER_PREFIX="student"
USERNAME="student"
PASSWORD="password123"
BASE_PORT=2220
OUTPUT_FILE="student_ssh_list.txt"

# 1. Install LXD
if ! command -v lxd >/dev/null 2>&1; then
    echo "[+] Installing LXD..."
    apt update
    apt install -y lxd
fi

# 2. Initialize LXD with NAT bridge if not already
if ! lxc network show lxdbr0 &>/dev/null; then
    echo "[+] Initializing LXD..."
    lxd init --auto
fi

echo "[+] Creating containers..."
> "$OUTPUT_FILE"

for i in $(seq 1 $NUM_CONTAINERS); do
    NAME="${CONTAINER_PREFIX}${i}"
    PORT=$((BASE_PORT + i))

    echo "[+] Launching $NAME..."
    lxc launch images:ubuntu/22.04 $NAME
    sleep 10

    echo "[+] Setting up user and SSH..."
    lxc exec $NAME -- bash -c "
        apt update && apt install -y openssh-server sudo
        adduser --disabled-password --gecos '' $USERNAME
        echo '$USERNAME:$PASSWORD' | chpasswd
        usermod -aG sudo $USERNAME
        systemctl enable ssh && systemctl restart ssh
    "

    echo "[+] Forwarding host port $PORT to container $NAME:22"
    lxc config device add $NAME sshport proxy listen=tcp:0.0.0.0:$PORT connect=tcp:127.0.0.1:22

    echo "$NAME => ssh $USERNAME@<SERVER_IP> -p $PORT (password: $PASSWORD)" >> "$OUTPUT_FILE"
done

echo "[✓] All containers ready. SSH info written to: $OUTPUT_FILE"
