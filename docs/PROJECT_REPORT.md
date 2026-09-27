# DevOps Capstone Project Report
## End-to-End DevOps Pipeline for a Node.js Web Application

**Author:** _[Your Name]_
**Date:** _[Submission Date]_
**Repository:** _[GitHub repo link]_
**Live Demo:** _[EC2 public IP or domain, if applicable]_

---

## 1. Introduction

This project implements a complete, end-to-end DevOps continuous delivery pipeline for a lightweight Node.js web application. The goal was to gain hands-on experience with the full lifecycle of modern software delivery: version control, continuous integration, containerization, cloud infrastructure provisioning, automated deployment, and production monitoring.

The application itself is intentionally simple — an Express.js server exposing a homepage, a JSON info endpoint, a health-check endpoint, and a Prometheus metrics endpoint — so that the project's focus stays on the **pipeline and infrastructure**, not application complexity.

**What the pipeline demonstrates:**
- Automated build and test on every Git push
- Docker image creation and versioned publishing to Docker Hub
- Zero-touch deployment to a remote EC2 host over SSH
- Infrastructure-level and application-level monitoring
- Scheduled maintenance (backups, log rotation) via cron

---

## 2. Architecture Diagram

```
┌────────────┐     git push      ┌──────────────┐
│  Developer │ ────────────────► │  GitHub Repo │
└────────────┘                   └──────┬───────┘
                                         │ webhook
                                         ▼
                              ┌────────────────────┐
                              │   Jenkins (EC2 #1)  │
                              │  ─────────────────  │
                              │  1. Checkout        │
                              │  2. npm install      │
                              │  3. npm test          │
                              │  4. docker build        │
                              │  5. docker push ─────────┼──► Docker Hub
                              │  6. ssh deploy              │
                              └──────────────┬───────────────┘
                                             │ ssh
                                             ▼
                              ┌────────────────────────┐
                              │     App EC2 (EC2 #2)     │
                              │  docker run app:latest    │
                              │                              │
                              │  ┌─────────────┐  ┌────────┐ │
                              │  │ Prometheus  │◄─┤  App    │ │
                              │  │  + Node     │  │ /metrics│ │
                              │  │  Exporter   │  └────────┘ │
                              │  └──────┬──────┘             │
                              │         ▼                     │
                              │    ┌─────────┐                │
                              │    │ Grafana │                │
                              │    └─────────┘                │
                              │                                │
                              │  cron ─► backup.sh              │
                              │  cron ─► log-cleanup.sh          │
                              └────────────────────────────────┘
```

*(See `README.md` for the same diagram in a more terminal-friendly form; a polished version should be captured as an image and inserted here in the DOCX/PDF export.)*

---

## 3. Tools & Services Used

| Category | Tool/Service | Purpose |
|---|---|---|
| Source Control | GitHub | Central code repository, triggers CI via webhook |
| CI/CD | Jenkins (self-hosted on EC2) | Orchestrates build, test, and deploy stages |
| Runtime | Node.js 20 + Express | Application runtime and web framework |
| Containerization | Docker (multi-stage build) | Packages the app into a portable, reproducible image |
| Image Registry | Docker Hub | Stores versioned application images |
| Cloud Infrastructure | AWS EC2 (Ubuntu 22.04) | Hosts Jenkins and the running application |
| (Optional) Storage | AWS S3 | Off-box backup storage |
| Monitoring | Prometheus | Scrapes and stores host + app metrics |
| Monitoring | Node Exporter | Exposes EC2 host-level metrics (CPU, memory, disk) |
| Visualization | Grafana | Dashboards for infrastructure and app metrics |
| Automation | Bash + Cron | Scheduled backups and log cleanup |

---

## 4. Pipeline Stages Explanation

The pipeline is defined declaratively in the `Jenkinsfile` at the repository root and runs automatically on every push to the main branch.

### Stage 1 — Checkout
Jenkins pulls the latest commit from the GitHub repository using the configured SCM settings.

### Stage 2 — Install Dependencies
Runs `npm ci` (falling back to `npm install`) inside the `app/` directory to install exact, locked dependency versions — ensuring reproducible builds.

### Stage 3 — Test
Runs `npm test`, which starts the app on a test port and hits `/health`, `/api/info`, and `/metrics` to confirm the server boots and responds correctly. A non-zero exit code here fails the pipeline immediately, preventing a broken build from reaching Docker Hub.

### Stage 4 — Docker Build
Builds a multi-stage Docker image: the first stage installs production dependencies, the second copies only the built artifacts into a minimal `node:20-alpine` runtime image running as a non-root user. The image is tagged with both the Jenkins build number (for traceability) and `latest`.

### Stage 5 — Docker Push
Authenticates to Docker Hub using Jenkins-managed credentials (`dockerhub-creds`) and pushes both tags.

### Stage 6 — Deploy to App EC2
Using an SSH Agent credential (`app-ec2-ssh-key`), Jenkins connects to the App EC2 instance, pulls the freshly pushed image, stops and removes the previous container, and starts the new one with the same port mapping and restart policy.

### Stage 7 — Post-Deploy Health Check
Curls the container's `/health` endpoint from the App EC2 host itself to confirm the new container actually came up successfully before declaring the pipeline green.

### Monitoring (continuous, not a pipeline stage)
Independent of Jenkins, Prometheus continuously scrapes the app's `/metrics` endpoint and Node Exporter's host metrics; Grafana visualizes both in a single dashboard.

### Automation (continuous, not a pipeline stage)
Cron jobs on the App EC2 run `backup.sh` nightly and `log-cleanup.sh` daily, independent of deployments.

---

## 5. Challenges & Learnings

*(Fill this section in with your own experience — sample entries below to adapt.)*

| Challenge | Root Cause | Resolution |
|---|---|---|
| Jenkins couldn't run `docker` commands | The `jenkins` user wasn't in the `docker` group | Ran `sudo usermod -aG docker jenkins` and restarted the Jenkins service |
| SSH deploy step failed with "Host key verification failed" | Jenkins had never connected to the App EC2 before | Added `-o StrictHostKeyChecking=no` in the pipeline (acceptable for a demo; in production, pre-seed `known_hosts` instead) |
| Node Exporter metrics not visible in Prometheus | Security group didn't allow inbound traffic on port 9100 | Opened port 9100 in the App EC2 security group |
| Docker Hub push failed with "unauthorized" | Credentials weren't scoped correctly / image name didn't match the Docker Hub namespace | Verified the `dockerhub-creds` username matched the image tag's namespace exactly |
| EC2 disk filled up after several days of testing | Docker layers, logs, and unused images accumulating | Implemented `log-cleanup.sh` with `docker system prune` on a daily cron schedule |

**General learnings:**
- Declarative Jenkinsfiles make pipeline logic version-controlled and reviewable alongside application code.
- Multi-stage Docker builds significantly reduce final image size and attack surface (no dev dependencies, no build tools in the runtime image).
- Running containers as a non-root user is a small change with a meaningful security benefit.
- Health-check-based deploy verification catches failures immediately rather than discovering them from user reports.
- Separating "deploy" (Jenkins-triggered) from "monitor/maintain" (cron-triggered) keeps each concern independently testable.

---

## 6. Screenshots

*(Insert screenshots here when preparing the final PDF/DOCX. Suggested captures:)*

1. GitHub repository structure
2. Jenkins pipeline job configuration
3. Jenkins console output showing all stages passing (green)
4. `docker images` output on the App EC2 showing the pulled image
5. `docker ps` output showing the running container
6. AWS EC2 console showing both running instances
7. Prometheus targets page (`/targets`) showing both scrape jobs as "UP"
8. Grafana dashboard with live CPU/memory/disk/request panels
9. Browser screenshot of the deployed app at `http://<APP_EC2_IP>:3000`
10. Terminal output of a manual `backup.sh` / `log-cleanup.sh` run

---

## 7. Deployment Link

- **Public URL:** `http://<APP_EC2_PUBLIC_IP>:3000`
- **Health Check:** `http://<APP_EC2_PUBLIC_IP>:3000/health`
- **Metrics:** `http://<APP_EC2_PUBLIC_IP>:3000/metrics`

*(If not publicly accessible, include a screenshot of the app running locally or via SSH tunnel as proof.)*

---

## 8. Conclusion

This capstone project brought together source control, CI/CD automation, containerization, cloud provisioning, monitoring, and shell-script-driven maintenance into a single, working delivery pipeline. Every push to GitHub now results in a tested, containerized, and automatically deployed application — with visibility into its health via Grafana and safeguards against disk exhaustion via scheduled cleanup. The project mirrors, at small scale, the same patterns used in production DevOps environments.
