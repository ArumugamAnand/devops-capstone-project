#!/bin/bash
#
# fast-track-userdata.sh
# Paste this into the EC2 "User data" box when launching your instance
# (Advanced Details > User data, as plain text). It auto-installs Docker,
# Docker Compose, and Jenkins in one shot so the instance is ready to use
# a few minutes after it boots — no manual SSH install steps needed.
#
# Launch settings to use:
#   AMI:            Ubuntu 22.04 LTS
#   Instance type:  t2.medium (t2.micro is too small to run Jenkins +
#                   Docker + Prometheus + Grafana together comfortably)
#   Security group inbound rules: 22 (SSH), 8080 (Jenkins), 3000 (App),
#                   9090 (Prometheus), 3001 (Grafana), 9100 (Node Exporter)
#     -> for a quick demo it's fine to allow these from "My IP" or 0.0.0.0/0,
#        just remember to terminate the instance when you're done.

set -e
exec > /var/log/user-data.log 2>&1

apt-get update -y
apt-get upgrade -y

# ---- Docker ----
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu
apt-get install -y docker-compose-plugin

# ---- Jenkins ----
apt-get install -y openjdk-17-jre
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y
apt-get install -y jenkins
usermod -aG docker jenkins
systemctl enable jenkins
systemctl restart jenkins

echo "Setup complete." > /home/ubuntu/setup-done.txt
