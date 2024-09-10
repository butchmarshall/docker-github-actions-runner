# Self-Hosted GitHub Actions Runner with Docker

This repository contains the setup for a self-hosted GitHub Actions runner using Docker and Docker Compose. It includes an environment with Node.js, Nx CLI, and Docker pre-installed, allowing you to run CI/CD pipelines that involve building Node-based Nx applications and interacting with Docker containers.

## Prerequisites

- Docker
- Docker Compose
- Access to the GitHub repository where the runner will be registered.

## Features

- **Node.js and npm**: Installed and managed via NVM (Node Version Manager) for flexibility with Node versions.
- **Nx CLI**: Installed globally to manage Nx workspaces and tasks.
- **Docker**: Installed to allow running Docker commands inside the runner, including the use of Docker-in-Docker.
- **Google Cloud SDK**: Installed to allow interaction with Google Cloud services, including Docker authentication with Google Container Registry (GCR).

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/butchmarshall/your-repo.git
cd your-repo
```
