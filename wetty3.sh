#!/bin/bash

NUM_STUDENTS=20
START_PORT=8001
NGINX_CONF="/etc/nginx/sites-available/class"
NGINX_LINK="/etc/nginx/sites-enabled/class"

echo "Creating $NUM_STUDENTS students with Wetty on ports $START_PORT and up"

# Create users and login messages
for i in $(seq 1 $NUM_STUDENTS); do
  USER="student$i"
  PORT=$((START_PORT + i - 1))

  echo "→ Adding user $USER"
  sudo adduser --disabled-password --gecos "" "$USER"

  # Show port info on login
  echo "echo '🌐 Your web terminal: http://<server-ip>/$USER'" | sudo tee -a /home/$USER/.bashrc > /dev/null
  echo "export STUDENT_PORT=$PORT" | sudo tee -a /home/$USER/.bashrc > /dev/null
  sudo chown $USER:$USER /home/$USER/.bashrc

  # Create systemd service
  SERVICE_PATH="/etc/systemd/system/wetty-$USER.service"
  sudo tee "$SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=Wetty for $USER
After=network.target

[Service]
ExecStart=/usr/local/bin/wetty --ssh-user=$USER --port=$PORT --ssh-host=localhost
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl enable wetty-$USER
  sudo systemctl start wetty-$USER
done

# Create Nginx config
echo "Setting up Nginx..."

sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
  listen 80;
  server_name _;

  # Allow larger data
  client_max_body_size 100M;
EOF

for i in $(seq 1 $NUM_STUDENTS); do
  USER="student$i"
  PORT=$((START_PORT + i - 1))

  sudo tee -a "$NGINX_CONF" > /dev/null <<EOF
  location /$USER/ {
    proxy_pass http://localhost:$PORT/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_read_timeout 3600s;
  }
EOF
done

sudo tee -a "$NGINX_CONF" > /dev/null <<EOF
}
EOF

# Enable Nginx config
sudo ln -sf "$NGINX_CONF" "$NGINX_LINK"
sudo nginx -t && sudo systemctl reload nginx

echo "✅ All done!"
echo "➡️ Students can access their terminals via: http://<server-ip>/student1/, ..., /student20/"
