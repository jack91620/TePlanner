#!/bin/bash
#
# TePlanner Service Stop Script
#

DEPLOY_DIR="/opt/teplanner"
PID_FILE="$DEPLOY_DIR/teplanner.pid"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "${YELLOW}Stopping TePlanner (PID: $PID)...${NC}"
        kill "$PID"
        sleep 2
        echo -e "${GREEN}Stopped${NC}"
    else
        echo "Process not running"
    fi
    rm -f "$PID_FILE"
else
    echo "PID file not found"
fi

# Also check port
PORT_PID=$(lsof -ti :8000 2>/dev/null || true)
if [ -n "$PORT_PID" ]; then
    echo -e "${YELLOW}Killing process on port 8000...${NC}"
    kill "$PORT_PID" 2>/dev/null || true
fi

echo -e "${GREEN}Service stopped${NC}"
