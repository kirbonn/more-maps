#!/bin/bash

# SETTINGS
NUM_CONTAINERS=10              # Change to how many you want
BASE_NAME="student"            # Container name prefix
IMAGE="ubuntu:22.04"           # Ubuntu LXD image
RAM_LIMIT="512MB"
CPU_LIMIT="1"
DISK_LIMIT="2GB"
DEFAULT_PASSWORD="student123"  # You can change this to anything secure

echo "Starting container setup..."

for i in $(seq -f "%02g" 1 $NUM_CONTAINERS); do
    NAME="${BASE_NAME}${i}"
    echo "Creating container: $NAME"

    # Launch container
    lxc launch $IMAGE $NAME

    # Set limits
    lxc config set $NAME limits.memory $RAM_LIMIT
    lxc config set $NAME limits.cpu $CPU_LIMIT
    lxc config device set $NAME root size=$DISK_LIMIT

    # Wait for container to be ready
    echo "Waiting for $NAME to get IP..."
    while [ -z "$(lxc list $NAME -c 4 | grep eth0 | awk '{print $2}')" ]; do
        sleep 1
    done

    # Install SSH and set password
    lxc exec $NAME -- bash -c "
        apt update &&
        apt install -y openssh-server &&
        systemctl enable ssh &&
        systemctl start ssh &&
        echo 'ubuntu:$DEFAULT_PASSWORD' | chpasswd
    "

    # Print container info
    IP=$(lxc list $NAME -c 4 | grep eth0 | awk '{print $2}')
    echo "$NAME is ready at IP: $IP (username: ubuntu, password: $DEFAULT_PASSWORD)"
    echo "------------------------------------------------------------"
done

echo "🎉 All $NUM_CONTAINERS set up!"
