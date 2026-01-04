#!/bin/bash
#
# TePlanner Deployment Script
# Deploys the backend to a remote server
#
# Usage:
#   ./deploy.sh <server_ip> [ssh_user]
#
# Example:
#   ./deploy.sh 123.45.67.89
#   ./deploy.sh 123.45.67.89 ubuntu
#

set -e

# Configuration
SERVER_IP=${1:-""}
SSH_USER=${2:-"root"}
REMOTE_DIR="/opt/teplanner"
LOCAL_BACKEND="$(dirname "$0")/../backend"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Usage: $0 <server_ip> [ssh_user]${NC}"
    echo "Example: $0 123.45.67.89 ubuntu"
    exit 1
fi

echo -e "${GREEN}=============================================="
echo "TePlanner Deployment"
echo "===============================================${NC}"
echo "Server: $SSH_USER@$SERVER_IP"
echo "Remote Dir: $REMOTE_DIR"
echo ""

# Check SSH connection
echo -e "${YELLOW}[1/5] Testing SSH connection...${NC}"
ssh -o ConnectTimeout=10 "$SSH_USER@$SERVER_IP" "echo 'SSH connection OK'" || {
    echo -e "${RED}Cannot connect to server. Check SSH configuration.${NC}"
    exit 1
}

# Create remote directory
echo -e "${YELLOW}[2/5] Creating remote directory...${NC}"
ssh "$SSH_USER@$SERVER_IP" "sudo mkdir -p $REMOTE_DIR && sudo chown \$USER:\$USER $REMOTE_DIR"

# Sync files (excluding sensitive files)
echo -e "${YELLOW}[3/5] Uploading files...${NC}"
rsync -avz --progress \
    --exclude '.env' \
    --exclude '*.pyc' \
    --exclude '__pycache__' \
    --exclude '.pytest_cache' \
    --exclude '*.db' \
    --exclude 'logs/' \
    --exclude '.git' \
    --exclude 'venv/' \
    --exclude '.venv/' \
    "$LOCAL_BACKEND/" "$SSH_USER@$SERVER_IP:$REMOTE_DIR/backend/"

# Upload deploy scripts
rsync -avz --progress \
    "$(dirname "$0")/" "$SSH_USER@$SERVER_IP:$REMOTE_DIR/deploy/"

# Install dependencies on server
echo -e "${YELLOW}[4/5] Installing dependencies on server...${NC}"
ssh "$SSH_USER@$SERVER_IP" << 'REMOTE_SCRIPT'
    cd /opt/teplanner/backend

    # Check if conda is available
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
        source $HOME/miniconda3/etc/profile.d/conda.sh
    elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
        source $HOME/anaconda3/etc/profile.d/conda.sh
    fi

    # Create and activate environment
    conda create -n teplanner python=3.11 -y 2>/dev/null || true
    conda activate teplanner

    # Install requirements
    pip install -r requirements.txt -q

    echo "Dependencies installed"
REMOTE_SCRIPT

# Remind about .env
echo -e "${YELLOW}[5/5] Deployment complete!${NC}"
echo ""
echo -e "${GREEN}=============================================="
echo "Deployment Successful!"
echo "===============================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. SSH to server: ssh $SSH_USER@$SERVER_IP"
echo "  2. Configure .env: nano $REMOTE_DIR/backend/.env"
echo "  3. Start service: cd $REMOTE_DIR && bash deploy/start_service.sh"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  - Update TESLA_REDIRECT_URI in .env to use server IP"
echo "  - Update Tesla Developer Portal with new redirect URI"
echo ""
