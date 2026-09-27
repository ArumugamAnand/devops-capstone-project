#!/usr/bin/env bash
#
# setup-app-ec2.sh
# One-time bootstrap script for the App EC2 instance (Ubuntu 22.04).
# Installs Docker, sets up backup/cleanup cron jobs, opens required ports.
#
# Usage (on the EC2 instance): sudo bash setup-app-ec2.sh

set -euo pipefail

echo "==> Updating packages..."
sudo apt-get update -y && sudo apt-get upgrade -y

echo "==> Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker "${USER}"
rm -f get-docker.sh

echo "==> Installing Docker Compose plugin..."
sudo apt-get install -y docker-compose-plugin

echo "==> Creating project + backup directories..."
sudo mkdir -p /opt/devops-capstone/scripts
sudo mkdir -p /opt/backups/devops-capstone-app
sudo mkdir -p /var/log/devops-capstone-app

echo "==> Copy scripts/backup.sh and scripts/log-cleanup.sh into /opt/devops-capstone/scripts/"
echo "    then chmod +x them and register the cron jobs below."

cat <<'EOF'

==> Suggested crontab entries (run: crontab -e):

# Nightly backup at 2 AM
0 2 * * * /opt/devops-capstone/scripts/backup.sh >> /var/log/capstone-backup.log 2>&1

# Log cleanup daily at 3:30 AM
30 3 * * * /opt/devops-capstone/scripts/log-cleanup.sh >> /var/log/capstone-cleanup.log 2>&1

EOF

echo "==> Done. Log out/in for the docker group change to take effect."
echo "==> Remember to open these inbound ports in the EC2 Security Group:"
echo "    22 (SSH), 3000 (App), 9090 (Prometheus), 3001 (Grafana), 9100 (Node Exporter)"
