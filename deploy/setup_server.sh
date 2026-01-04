#!/bin/bash
#
# TePlanner Server Setup Script
# Run this on a fresh Ubuntu 22.04 server
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/xxx/teplanner/main/deploy/setup_server.sh | bash
#   or
#   bash setup_server.sh
#

set -e

echo "=============================================="
echo "TePlanner Server Setup"
echo "=============================================="

# Update system
echo "[1/6] Updating system..."
sudo apt update && sudo apt upgrade -y

# Install dependencies
echo "[2/6] Installing dependencies..."
sudo apt install -y \
    python3.11 \
    python3.11-venv \
    python3-pip \
    git \
    nginx \
    supervisor \
    curl \
    wget \
    unzip

# Install Miniconda (lighter than Anaconda)
echo "[3/6] Installing Miniconda..."
if [ ! -d "$HOME/miniconda3" ]; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p $HOME/miniconda3
    rm /tmp/miniconda.sh
fi

# Initialize conda
source $HOME/miniconda3/etc/profile.d/conda.sh

# Create project directory
echo "[4/6] Creating project directory..."
sudo mkdir -p /opt/teplanner
sudo chown $USER:$USER /opt/teplanner

# Create conda environment
echo "[5/6] Creating conda environment..."
conda create -n teplanner python=3.11 -y || true
conda activate teplanner

# Create necessary directories
echo "[6/6] Creating directories..."
mkdir -p /opt/teplanner/logs
mkdir -p /opt/teplanner/backend

echo ""
echo "=============================================="
echo "Server setup complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Upload your code to /opt/teplanner/backend"
echo "  2. Run: cd /opt/teplanner/backend && pip install -r requirements.txt"
echo "  3. Copy .env.example to .env and configure"
echo "  4. Run: bash deploy/configure_nginx.sh"
echo "  5. Run: bash deploy/start_service.sh"
echo ""
