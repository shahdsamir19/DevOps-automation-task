CI/CD with Terraform, Docker, Ansible & GCP
📌 Project Overview

This project sets up a CI/CD pipeline using Terraform (for infrastructure as code), Docker (for containerization), Ansible (for automation), and GCP (Google Cloud Platform).
The pipeline provisions infrastructure, builds and pushes Docker images, and automatically deploys them to production — with zero manual configuration on the production VM.

🏗️ Stage 0: Infrastructure Provisioning

Tools: Terraform, Ansible, GCP

Create a custom VPC and firewall rules.

Provision two VMs:

CICD VM: Acts as the build server (Docker + pipeline execution).

Production VM: Hosts the deployed Docker container.

Ansible provisioning is triggered automatically from Terraform to install required dependencies (e.g., Docker, Ansible, Git).

Terraform dynamically generates an inventory.ini with the public IPs and SSH details for Ansible.

✅ Outcome: CICD machine ready to build/push images. Production machine ready for automated deployment.

🐳 Stage 1: Build the Dockerfile

Write a Dockerfile for your application (example: Node.js app):

FROM node:18-alpine

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]


Build the Docker image inside the CICD machine:

docker build -t gcr.io/PROJECT_ID/myapp:latest .


✅ Outcome: A Docker image is built locally in the CICD VM.

📦 Stage 2: Push Docker Image to Private Registry

Authenticate with GCP Artifact Registry / Container Registry:

gcloud auth configure-docker


Push image to private registry:

docker push gcr.io/PROJECT_ID/myapp:latest


✅ Outcome: Image is stored in a secure private registry (Artifact Registry / Container Registry).

⚡ Stage 3: Automated Deployment on Production VM

Ansible playbook for deployment (ansible/playbook.yml)

- hosts: prod
  become: yes
  tasks:
    - name: Install Docker (if not installed)
      apt:
        name: docker.io
        state: present
        update_cache: yes

    - name: Authenticate Docker with GCP
      shell: |
        gcloud auth configure-docker --quiet

    - name: Pull Docker image from registry
      shell: |
        docker pull gcr.io/PROJECT_ID/myapp:latest

    - name: Stop old container (if exists)
      shell: |
        docker rm -f myapp || true

    - name: Run new container
      shell: |
        docker run -d -p 80:3000 --name myapp gcr.io/PROJECT_ID/myapp:latest


Pipeline flow:

CICD machine builds and pushes the image.

Ansible connects to Production VM (via SSH + private key).

Ansible installs Docker (if needed).

Ansible pulls the image from the private registry.

Ansible runs the container and exposes the application.

✅ Outcome: The application is deployed and accessible via the Production VM public IP.

📊 Final Architecture

Terraform → Creates CICD + Production VMs, networking, firewall.

Ansible → Configures CICD + Production machines.

Docker → Builds application images.

GCP Artifact Registry → Stores images securely.

Pipeline → Fully automated: no manual steps on Production VM.

🎯 End-to-End Workflow

terraform apply

Creates infrastructure.

Generates inventory.ini.

Runs Ansible bootstrap.

On CICD machine → Run pipeline (manually or automated):

Build Docker image.

Push image to registry.

Trigger Ansible deployment on Production VM.

On Production VM:

Ansible deploys containerized app automatically.

✅ Application is live in production with CI/CD automation.
