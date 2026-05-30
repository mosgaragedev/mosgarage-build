#!/bin/bash
set -e
echo "WSL init started..."

sudo apt update && sudo apt upgrade -y

sudo apt install -y git build-essential curl wget unzip zip apt-transport-https ca-certificates gnupg lsb-release

# .NET SDK (example for Ubuntu 22.04) - adapt for other Ubuntu versions
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb || true
sudo dpkg -i packages-microsoft-prod.deb || true
sudo apt update
sudo apt install -y dotnet-sdk-8.0 || true

# Node.js & npm
sudo apt install -y nodejs npm || true

# Python & pip
sudo apt install -y python3 python3-pip || true

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash || true

# GitHub CLI
type -p curl >/dev/null || sudo apt install -y curl
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh || true

# Docker Engine (optional)
sudo apt install -y docker.io || true
sudo usermod -aG docker $USER || true

# Dev Containers CLI
sudo apt install -y npm
sudo npm install -g @devcontainers/cli || true

# Performance
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p || true

echo "WSL init complete."
