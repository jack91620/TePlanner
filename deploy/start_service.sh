#!/bin/bash
#
# TePlanner Service Start Script
# Run this on the server to start the backend service
#

set -e

DEPLOY_DIR="/opt/teplanner"
BACKEND_DIR="$DEPLOY_DIR/backend"
LOG_DIR="$DEPLOY_DIR/logs"
PID_FILE="$DEPLOY_DIR/teplanner.pid"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create log directory
mkdir -p "$LOG_DIR"

# Activate conda
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source $HOME/miniconda3/etc/profile.d/conda.sh
elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source $HOME/anaconda3/etc/profile.d/conda.sh
fi

conda activate teplanner

# Stop existing process
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo -e "${YELLOW}Stopping existing process (PID: $OLD_PID)...${NC}"
        kill "$OLD_PID" 2>/dev/null || true
        sleep 2
    fi
    rm -f "$PID_FILE"
fi

# Also check port 8000
PORT_PID=$(lsof -ti :8000 2>/dev/null || true)
if [ -n "$PORT_PID" ]; then
    echo -e "${YELLOW}Killing process on port 8000 (PID: $PORT_PID)...${NC}"
    kill "$PORT_PID" 2>/dev/null || true
    sleep 1
fi

# Check .env file
if [ ! -f "$BACKEND_DIR/.env" ]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    echo "Please create $BACKEND_DIR/.env from .env.example"
    exit 1
fi

cd "$BACKEND_DIR"

# Start service
echo -e "${GREEN}Starting TePlanner backend...${NC}"
nohup uvicorn app.main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers 2 \
    > "$LOG_DIR/uvicorn.log" 2>&1 &

echo $! > "$PID_FILE"
sleep 2

# Check if started successfully
if kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    # Get public IP
    PUBLIC_IP=$(curl -s http://ipinfo.io/ip 2>/dev/null || curl -s http://icanhazip.com 2>/dev/null || echo "unknown")

    echo -e "${GREEN}=============================================="
    echo "TePlanner Started Successfully!"
    echo "===============================================${NC}"
    echo ""
    echo "PID: $(cat $PID_FILE)"
    echo "Log: $LOG_DIR/uvicorn.log"
    echo ""
    echo -e "${GREEN}Public URL: http://$PUBLIC_IP:8000${NC}"
    echo ""
    echo "Endpoints:"
    echo "  - Health: http://$PUBLIC_IP:8000/health"
    echo "  - API Docs: http://$PUBLIC_IP:8000/docs"
    echo "  - Tesla Auth: http://$PUBLIC_IP:8000/api/v1/auth/tesla/authorize"
    echo ""
    echo -e "${YELLOW}Don't forget to:${NC}"
    echo "  1. Open port 8000 in security group"
    echo "  2. Update Tesla Developer Portal redirect URI"
    echo "  3. Update .env TESLA_REDIRECT_URI"
    echo ""
else
    echo -e "${RED}Failed to start service!${NC}"
    echo "Check logs: tail -f $LOG_DIR/uvicorn.log"
    exit 1
fi
