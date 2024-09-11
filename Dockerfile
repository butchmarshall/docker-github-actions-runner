FROM ubuntu:24.04

ENV RUNNER_VERSION="2.319.1"
ARG GID="140"

# Prevents installdependencies.sh from prompting the user and blocking the image creation
ARG DEBIAN_FRONTEND=noninteractive

# Install necessary packages for Node-based Nx app, including Node.js, npm, git, and build-essential tools
RUN apt update -y && apt upgrade -y && useradd -m docker \
    && apt install -y --no-install-recommends \
    curl jq build-essential libssl-dev libffi-dev python3 python3-venv python3-dev python3-pip libicu-dev \
    nodejs npm git \
    && npm install -g npm@latest # Ensure npm is updated to the latest version

# Install nvm (Node Version Manager) and set default Node.js version (optional, if you want flexibility with Node versions)
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash \
    && export NVM_DIR="$HOME/.nvm" \
    && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
    && nvm install 20 \
    && nvm use 20 \
    && nvm alias default 20

# Install Nx CLI globally
RUN npm install -g nx

# GitHub Actions Runner setup
RUN cd /home/docker && mkdir docker-github-actions-runner && cd docker-github-actions-runner \
  && curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz  \
  && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

RUN chown -R docker ~docker && /home/docker/docker-github-actions-runner/bin/installdependencies.sh

# Install Docker
RUN apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
    apt-get update && apt-get install -y docker-ce-cli


# Add the "docker" user to the "docker" group
RUN if getent group docker; then \
      existing_gid=$(getent group docker | cut -d: -f3); \
      if [ "$existing_gid" != "$GID" ]; then \
        groupmod -g "$GID" docker; \
      fi; \
    else \
      groupadd -g "$GID" docker; \
    fi && usermod -aG docker docker

# Add gcloud and utilities
RUN mkdir -p /home/docker \
  && curl -o /home/docker/google-cloud-cli-linux-x86_64.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz \
  && tar -xf /home/docker/google-cloud-cli-linux-x86_64.tar.gz -C /home/docker \
  && /home/docker/google-cloud-sdk/install.sh \
  && ln -s /home/docker/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud 


 RUN gcloud components install docker-credential-gcr \
   && gcloud auth configure-docker \
   && ln -s /home/docker/google-cloud-sdk/bin/docker-credential-gcloud /usr/local/bin/docker-credential-gcloud 


COPY entrypoint.sh entrypoint.sh

# Make the script executable
RUN chmod +x entrypoint.sh

# Since the config and run script for actions are not allowed to be run by root,
# Set the user to "docker" so all subsequent commands are run as the docker user
USER docker


# Ensure Node.js, npm, and Nx are accessible in subsequent commands
ENV PATH="/home/docker/.nvm/versions/node/v20.x.x/bin:$PATH"

ENTRYPOINT ["./entrypoint.sh"]
