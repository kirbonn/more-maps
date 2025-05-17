#!/bin/bash
# Script to set up 25 LXD containers for classroom use with SSH access

# Step 1: Update the system and install LXD
sudo apt update && sudo apt upgrade -y
sudo snap install lxd

# Step 2: Initialize LXD
sudo lxd init --auto --storage-backend=dir --network-address=0.0.0.0

# Step 3: Install dependencies for student projects
sudo apt install -y nginx samba nodejs npm

# Step 4: Create a template container with resource limits
lxc init template -p default
lxc config set template limits.cpu 1
lxc config set template limits.memory 256MB

# Step 5: Clone containers for each student (student1 to student25)
for i in {1..10}; do
  lxc copy template student$i
  lxc start student$i
done

# Step 6: Configure SSH and user accounts in each container
for i in {1..10}; do
  lxc exec student$i -- apt update
  lxc exec student$i -- apt install -y openssh-server
  lxc exec student$i -- systemctl enable --now ssh
  lxc exec student$i -- useradd -m -s /bin/bash user$i
  lxc exec student$i -- sh -c "echo 'user$i:password$i' | chpasswd"
done

# Step 7: Set up port forwarding for websites (host port 8001-8025 to container port 80)
for i in {1..10}; do
  lxc config device add student$i webproxy proxy listen=tcp:0.0.0.0:$((8000+i)) connect=tcp:127.0.0.1:80
done

# Step 8: Configure firewall to allow SSH and website ports
sudo ufw allow 22/tcp
sudo ufw allow 8001:8025/tcp
sudo ufw enable

# Step 9: Output container IPs and access details
echo "Container setup complete. Access details:"
for i in {1..10}; do
  IP=$(lxc list | grep student$i | awk '{print $6}')
  echo "Container: student$i, IP: $IP, SSH: ssh user$i@$IP, Password: password$i, Website: http://<server-ip>:$((8000+i))"
done
