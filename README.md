# DevOps Capstone Project — End-to-End CI/CD Pipeline

An end-to-end DevOps pipeline for a Node.js web application: source control on GitHub, CI/CD with Jenkins, containerization with Docker, hosting on AWS EC2, and monitoring with Prometheus + Grafana. Backups and log cleanup are automated with Bash + cron.

## Tech Stack

| Layer | Tools/Tech |
|---|---|
| Source Control | Git + GitHub |
| CI/CD | Jenkins (running on an EC2 instance) |
| Application | Node.js (Express) |
| Containerization | Docker + Docker Hub |
| Infra | AWS EC2 (Ubuntu) |
| Monitoring | Prometheus, Grafana, Node Exporter |
| Scripting & Jobs | Bash + Cron |

## Architecture

```
Developer
   │  git push
   ▼
GitHub Repo
   │  webhook trigger
   ▼
Jenkins (EC2 #1)
   │  1. Checkout
   │  2. npm install
   │  3. npm test
   │  4. docker build
   │  5. docker push  ───────────► Docker Hub
   │  6. ssh deploy
   ▼
App EC2 (EC2 #2)
   │  docker run devops-capstone-app
   │
   ├── Prometheus (scrapes /metrics + Node Exporter) ─► Grafana dashboards
   └── Cron jobs ─► backup.sh / log-cleanup.sh
```

## Repository Structure

```
devops-capstone-project/
├── app/                          # Node.js application source
│   ├── server.js
│   ├── package.json
│   ├── public/index.html
│   └── test/basic.test.js
├── Dockerfile                    # Multi-stage build for the app
├── docker-compose.yml            # Run the app locally
├── Jenkinsfile                   # CI/CD pipeline definition
├── monitoring/
│   ├── docker-compose.monitoring.yml
│   ├── prometheus.yml
│   └── grafana-provisioning/     # Auto-provisioned datasource + dashboard
├── scripts/
│   ├── backup.sh                 # Cron: nightly backup
│   ├── log-cleanup.sh            # Cron: daily log/disk cleanup
│   └── setup-app-ec2.sh          # One-time EC2 bootstrap (installs Docker etc.)
└── docs/
    └── PROJECT_REPORT.md         # Full capstone report (convert to PDF/DOCX for submission)
```

## 1. Run the App Locally

```bash
cd app
npm install
npm start
# App:      http://localhost:3000
# Health:   http://localhost:3000/health
# Metrics:  http://localhost:3000/metrics
```

Or with Docker Compose:

```bash
docker compose up --build
```

## 2. Build & Push the Docker Image Manually

```bash
docker build -t <dockerhub-username>/devops-capstone-app:latest .
docker login
docker push <dockerhub-username>/devops-capstone-app:latest
```

## 3. Provision AWS EC2 Instances

Launch **two** Ubuntu 22.04 EC2 instances (t2.micro is fine for a demo):

1. **Jenkins EC2** — installs Jenkins, builds, and deploys.
2. **App EC2** — runs the Docker container and monitoring stack.

Security group inbound rules needed:

| Port | Purpose | Instance |
|---|---|---|
| 22 | SSH | Both |
| 8080 | Jenkins UI | Jenkins EC2 |
| 3000 | App | App EC2 |
| 9090 | Prometheus | App EC2 |
| 3001 | Grafana | App EC2 |
| 9100 | Node Exporter | App EC2 |

On the **App EC2**, run the bootstrap script:

```bash
scp scripts/setup-app-ec2.sh ubuntu@<APP_EC2_IP>:~
ssh ubuntu@<APP_EC2_IP>
sudo bash setup-app-ec2.sh
```

## 4. Install Jenkins (Jenkins EC2)

```bash
sudo apt update
sudo apt install -y openjdk-17-jre docker.io
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list
sudo apt update && sudo apt install -y jenkins
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

Then open `http://<JENKINS_EC2_IP>:8080`, unlock Jenkins, and install the **Git**, **Docker Pipeline**, and **SSH Agent** plugins.

### Jenkins Credentials to Configure

| ID | Type | Purpose |
|---|---|---|
| `dockerhub-creds` | Username/Password | Push images to Docker Hub |
| `app-ec2-ssh-key` | SSH Username with Private Key | Deploy over SSH to App EC2 |

### Create the Pipeline Job

1. New Item → Pipeline → point it at this GitHub repo.
2. Enable **GitHub hook trigger for GITScm polling** (or poll SCM) so pushes auto-trigger builds.
3. Pipeline script from SCM → `Jenkinsfile` at repo root.
4. Edit the `APP_EC2_HOST` placeholder in the `Jenkinsfile` to match your App EC2's address.

## 5. CI/CD Flow (Jenkinsfile stages)

1. **Checkout** — pulls the latest commit from GitHub.
2. **Install Dependencies** — `npm ci` inside `app/`.
3. **Test** — runs the smoke test suite (`npm test`); fails the build on error.
4. **Docker Build** — builds the image, tagged with the Jenkins build number and `latest`.
5. **Docker Push** — logs in and pushes both tags to Docker Hub.
6. **Deploy to App EC2** — SSHes into the App EC2, pulls the new image, stops/removes the old container, and starts the new one.
7. **Post-Deploy Health Check** — curls `/health` on the deployed container and fails the pipeline if it doesn't return 200.

## 6. Monitoring Stack

On the App EC2:

```bash
cd monitoring
docker compose -f docker-compose.monitoring.yml up -d
```

- Prometheus: `http://<APP_EC2_IP>:9090` — scrapes Node Exporter (`:9100`) and the app's own `/metrics` endpoint.
- Grafana: `http://<APP_EC2_IP>:3001` (default `admin` / `admin`) — the **DevOps Capstone - EC2 & App Overview** dashboard is auto-provisioned with CPU, memory, disk, request rate, and p95 latency panels.

## 7. Backups & Log Cleanup (Cron)

Copy `scripts/backup.sh` and `scripts/log-cleanup.sh` to `/opt/devops-capstone/scripts/` on the App EC2, `chmod +x` them, then add to `crontab -e`:

```cron
# Nightly backup at 2 AM
0 2 * * * /opt/devops-capstone/scripts/backup.sh >> /var/log/capstone-backup.log 2>&1

# Daily log/disk cleanup at 3:30 AM
30 3 * * * /opt/devops-capstone/scripts/log-cleanup.sh >> /var/log/capstone-cleanup.log 2>&1
```

`backup.sh` optionally uploads to S3 if you export `S3_BUCKET=your-bucket-name` in the cron environment.

## 8. Deliverables Checklist

- [ ] Push this repo to GitHub
- [ ] Provision Jenkins EC2 + App EC2
- [ ] Configure Jenkins credentials and pipeline job
- [ ] Trigger a build, confirm all stages pass
- [ ] Confirm the app is reachable at `http://<APP_EC2_IP>:3000`
- [ ] Stand up Prometheus + Grafana, confirm dashboard populates
- [ ] Set up cron jobs, verify a manual run of each script
- [ ] Take screenshots of: Jenkins console output, Docker images (`docker images`), EC2 console, Grafana dashboard
- [ ] Fill in `docs/PROJECT_REPORT.md` and convert to PDF/DOCX for submission

## License

MIT — free to use for learning and coursework.
