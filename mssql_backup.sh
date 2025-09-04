#!/bin/bash

# =========================
# Configuration
# =========================
CONTAINER_NAME="mssql2019"
MSSQL_IMAGE="mcr.microsoft.com/mssql/server:2019-latest"
VOLUME_NAME="mssql2019_data"

# =========================
# Check Docker installation
# =========================
if ! command -v docker &> /dev/null; then
    echo "🚀 Docker not found. Installing..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    echo "✅ Docker installed successfully. Please log out and log back in if you want to use docker without sudo."
else
    echo "✅ Docker is already installed."
fi

# =========================
# Check Docker volume
# =========================
if ! docker volume ls | grep -q "$VOLUME_NAME"; then
    echo "📦 Creating Docker volume: $VOLUME_NAME"
    docker volume create "$VOLUME_NAME"
else
    echo "📦 Docker volume '$VOLUME_NAME' already exists."
fi

# =========================
# Check container
# =========================
if docker container inspect "$CONTAINER_NAME" > /dev/null 2>&1; then
    RUNNING=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")
    if [ "$RUNNING" = "true" ]; then
        echo "✅ Container '$CONTAINER_NAME' is already running."
    else
        echo "▶️ Starting existing container '$CONTAINER_NAME'..."
        docker start "$CONTAINER_NAME"
        echo "✅ Container '$CONTAINER_NAME' started."
    fi
else
    echo "🚧 Creating MSSQL container '$CONTAINER_NAME'..."
    echo "⚠️ Please set SA_PASSWORD environment variable before running this script."
    echo "Example: export SA_PASSWORD='YourStrong!Passw0rd'"
    if [ -z "$SA_PASSWORD" ]; then
        echo "❌ SA_PASSWORD not set. Aborting."
        exit 1
    fi
    docker run -e "ACCEPT_EULA=Y" \
               -e "SA_PASSWORD=$SA_PASSWORD" \
               -e "TZ=$(cat /etc/timezone)" \
               -p 11433:1433 \
               --name "$CONTAINER_NAME" \
               --volume "$VOLUME_NAME:/var/opt/mssql" \
               --restart always \
               -d "$MSSQL_IMAGE"
    echo "✅ Container '$CONTAINER_NAME' created and running."
fi

# =========================
# Check/install sqlcmd on host
# =========================
if ! command -v sqlcmd &> /dev/null; then
    echo "🚀 Installing sqlcmd tools on host..."
    curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
    sudo apt update
    sudo ACCEPT_EULA=Y apt install -y mssql-tools unixodbc-dev
    echo 'export PATH="$PATH:/opt/mssql-tools/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    echo "✅ sqlcmd installed successfully."
else
    echo "✅ sqlcmd is already installed."
fi

# =========================
# Prompt to connect (manual)
# =========================
echo "ℹ️ To connect to SQL Server, run:"
echo "sqlcmd -S localhost,11433 -U SA -P \"<YourPassword>\""
