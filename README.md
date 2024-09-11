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
git clone https://github.com/butchmarshall/docker-github-actions-runner.git
cd docker-github-actions-runner
```

### 2. Build Image

We must build the base image with the GID of the docker group in order to bind to the docker socket

Replace `<YOUR_GITHUB_RUNNER_TOKEN>` with the runner token found under [Settings -> Actions -> Runners] of your repository.

Replace `<GITHUB_RUNNER_TARGET_REPO>` with the repository you want to use your runner with (e.g. butchmarshall/docker-github-actions-runner)

```bash
TOKEN=<YOUR_GITHUB_RUNNER_TOKEN> REPO=<GITHUB_RUNNER_TARGET_REPO> GID=$(getent group docker | cut -d: -f3); docker compose build
```

## Example Github Action

This example github action uses NX to determine all affect apps, build their dockerfile(s) and pushes them to their respective GCP Artifact Registry

```yaml
name: CI

on:
  push:
    branches:
      - main
  pull_request:

permissions:
  actions: read
  contents: read

jobs:
  main:
    runs-on: self-hosted
    env:
      REGION: "northamerica-northeast2" # Set your desired region
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # Ensure Node.js is installed before running npx commands
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: "npm"

      # Cache node_modules
      - run: npm ci --legacy-peer-deps

      - uses: nrwl/nx-set-shas@v4

      # Use `nx show projects --affected` to determine what has been affected
      - name: Determine affected apps
        shell: bash
        run: |
          npx nx show projects --affected > affected-apps.txt
          cat affected-apps.txt

      # Only build if there are affected apps
      - name: Build affected apps
        shell: bash
        run: |
          affected_apps=$(cat affected-apps.txt)

          # Check if affected_apps is empty
          if [ -z "$affected_apps" ]; then
            echo "No affected apps found"
            exit 0
          fi

          # Initialize a success flag to track build results
          build_success=true

          # Loop through each affected app and build it
          for app in $affected_apps; do
            echo "Building $app"
            
            # Try to build the Docker image for each app
            if ! docker build -t ${REGION}-docker.pkg.dev/${{ secrets.GCP_PROJECT_ID }}/$app/$app:${{ github.sha }} -t gcr.io/${{ secrets.GCP_PROJECT_ID }}/$app:${{ github.sha }} -f apps/$app/Dockerfile .; then
              echo "Docker build failed for $app"
              build_success=false
            else
              echo "Docker build succeeded for $app"
            fi
          done

          # Check if any builds failed and exit accordingly
          if [ "$build_success" = false ]; then
            echo "Some builds failed."
            exit 1
          else
            echo "All builds completed successfully."
          fi

      # Authenticate to Google Cloud and capture the credentials file path
      - name: Authenticate to Google Cloud
        id: auth
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_CREDENTIALS }}

      # Configure Docker to use gcloud credentials for Artifact Registry
      - name: Configure Docker to use gcloud credentials
        run: |
          echo "Configuring Docker with gcloud credentials. ${GOOGLE_APPLICATION_CREDENTIALS} --- ${CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE}"
          gcloud auth configure-docker ${REGION}-docker.pkg.dev

      # Push affected Docker images to Artifact Registry
      - name: Push Docker images to Artifact Registry
        shell: bash
        run: |
          affected_apps=$(cat affected-apps.txt)
          if [ -z "$affected_apps" ]; then
            echo "No affected apps found"
            exit 0
          fi
          for app in $affected_apps; do
            docker push ${REGION}-docker.pkg.dev/${{ secrets.GCP_PROJECT_ID }}/$app/$app:${{ github.sha }}
          done
```
