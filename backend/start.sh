#!/bin/bash
#
# TePlanner Backend Startup Script
#
# Usage:
#   ./start.sh          # Start server (default port 8000)
#   ./start.sh -p 8080  # Start on custom port
#   ./start.sh -d       # Start in daemon mode (background)
#   ./start.sh -k       # Kill existing server
#   ./start.sh -r       # Restart server
#

set -e

# Configuration
DEFAULT_PORT=8000
DEFAULT_HOST="0.0.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONDA_ENV="teplanner"
CONDA_BASE="$HOME/anaconda3"
PID_FILE="$SCRIPT_DIR/.server.pid"
LOG_FILE="$SCRIPT_DIR/server.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
PORT=$DEFAULT_PORT
HOST=$DEFAULT_HOST
DAEMON_MODE=false
KILL_MODE=false
RESTART_MODE=false
RELOAD=true

while getopts "p:h:dkrn" opt; do
    case $opt in
        p) PORT="$OPTARG" ;;
        h) HOST="$OPTARG" ;;
        d) DAEMON_MODE=true ;;
        k) KILL_MODE=true ;;
        r) RESTART_MODE=true ;;
        n) RELOAD=false ;;
        *)
            echo "Usage: $0 [-p port] [-h host] [-d] [-k] [-r] [-n]"
            echo "  -p PORT   Server port (default: $DEFAULT_PORT)"
            echo "  -h HOST   Server host (default: $DEFAULT_HOST)"
            echo "  -d        Daemon mode (run in background)"
            echo "  -k        Kill existing server"
            echo "  -r        Restart server"
            echo "  -n        No reload (production mode)"
            exit 1
            ;;
    esac
done

# Function to find process using port
find_port_pid() {
    local port=$1
    lsof -ti :$port 2>/dev/null || true
}

# Function to kill process on port
kill_port_process() {
    local port=$1
    local pid=$(find_port_pid $port)

    if [ -n "$pid" ]; then
        echo -e "${YELLOW}Killing process $pid on port $port...${NC}"
        kill $pid 2>/dev/null || true
        sleep 1

        # Force kill if still running
        if kill -0 $pid 2>/dev/null; then
            echo -e "${YELLOW}Force killing process $pid...${NC}"
            kill -9 $pid 2>/dev/null || true
            sleep 1
        fi

        echo -e "${GREEN}Process killed${NC}"
        return 0
    else
        echo -e "${GREEN}No process running on port $port${NC}"
        return 1
    fi
}

# Function to kill server from PID file
kill_server() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            echo -e "${YELLOW}Stopping server (PID: $pid)...${NC}"
            kill $pid 2>/dev/null || true
            sleep 2
            if kill -0 $pid 2>/dev/null; then
                kill -9 $pid 2>/dev/null || true
            fi
            echo -e "${GREEN}Server stopped${NC}"
        fi
        rm -f "$PID_FILE"
    fi

    # Also check port
    kill_port_process $PORT
}

# Kill mode
if [ "$KILL_MODE" = true ]; then
    kill_server
    exit 0
fi

# Restart mode
if [ "$RESTART_MODE" = true ]; then
    kill_server
    sleep 1
fi

# Check if port is in use
existing_pid=$(find_port_pid $PORT)
if [ -n "$existing_pid" ]; then
    echo -e "${YELLOW}Port $PORT is already in use by process $existing_pid${NC}"
    read -p "Kill existing process? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        kill_port_process $PORT
    else
        echo -e "${RED}Aborted${NC}"
        exit 1
    fi
fi

# Change to script directory
cd "$SCRIPT_DIR"

# Activate conda environment
echo -e "${GREEN}Activating conda environment: $CONDA_ENV${NC}"
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate $CONDA_ENV

# Check .env file
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Warning: .env file not found${NC}"
    if [ -f ".env.example" ]; then
        echo "Copying from .env.example..."
        cp .env.example .env
    fi
fi

# Build uvicorn command
UVICORN_CMD="uvicorn app.main:app --host $HOST --port $PORT"
if [ "$RELOAD" = true ]; then
    UVICORN_CMD="$UVICORN_CMD --reload"
fi

echo -e "${GREEN}Starting TePlanner Backend...${NC}"
echo -e "  Host: $HOST"
echo -e "  Port: $PORT"
echo -e "  Reload: $RELOAD"
echo -e "  Daemon: $DAEMON_MODE"
echo ""

if [ "$DAEMON_MODE" = true ]; then
    # Run in background
    echo -e "${GREEN}Starting in daemon mode...${NC}"
    nohup $UVICORN_CMD > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 2

    if kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo -e "${GREEN}Server started successfully${NC}"
        echo -e "  PID: $(cat $PID_FILE)"
        echo -e "  Log: $LOG_FILE"
        echo -e "  URL: http://$HOST:$PORT"
        echo ""
        echo "To stop: $0 -k"
        echo "To view logs: tail -f $LOG_FILE"
    else
        echo -e "${RED}Failed to start server${NC}"
        cat "$LOG_FILE"
        exit 1
    fi
else
    # Run in foreground
    echo -e "${GREEN}Starting in foreground mode (Ctrl+C to stop)${NC}"
    echo ""
    exec $UVICORN_CMD
fi
