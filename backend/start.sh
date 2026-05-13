#!/bin/bash
#
# TePlanner Backend Startup Script with Tesla API Initialization
#
# Usage:
#   ./start.sh          # Start server and initialize Tesla API
#   ./start.sh -p 8080  # Start on custom port
#   ./start.sh -d       # Start in daemon mode (background)
#   ./start.sh -k       # Kill existing server
#   ./start.sh -r       # Restart server
#   ./start.sh -s       # Skip Tesla API initialization
#

set -e

# Configuration
DEFAULT_PORT=8000
DEFAULT_HOST="127.0.0.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONDA_ENV="teplanner"
CONDA_BASE="$HOME/anaconda3"
# Support miniconda as well
if [ ! -d "$CONDA_BASE" ]; then
    CONDA_BASE="$HOME/miniconda3"
fi
PID_FILE="$SCRIPT_DIR/.server.pid"
LOG_FILE="$SCRIPT_DIR/server.log"

# Tesla API Configuration
TESLA_AUTH_URL="https://auth.tesla.cn/oauth2/v3/token"
TESLA_FLEET_API="https://fleet-api.prd.cn.vn.cloud.tesla.cn"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
PORT=$DEFAULT_PORT
HOST=$DEFAULT_HOST
DAEMON_MODE=false
KILL_MODE=false
RESTART_MODE=false
RELOAD=true
SKIP_TESLA=false

while getopts "p:h:dkrns" opt; do
    case $opt in
        p) PORT="$OPTARG" ;;
        h) HOST="$OPTARG" ;;
        d) DAEMON_MODE=true ;;
        k) KILL_MODE=true ;;
        r) RESTART_MODE=true ;;
        n) RELOAD=false ;;
        s) SKIP_TESLA=true ;;
        *)
            echo "Usage: $0 [-p port] [-h host] [-d] [-k] [-r] [-n] [-s]"
            echo "  -p PORT   Server port (default: $DEFAULT_PORT)"
            echo "  -h HOST   Server host (default: $DEFAULT_HOST)"
            echo "  -d        Daemon mode (run in background)"
            echo "  -k        Kill existing server"
            echo "  -r        Restart server"
            echo "  -n        No reload (production mode)"
            echo "  -s        Skip Tesla API initialization"
            exit 1
            ;;
    esac
done

# Refuse to run under daemon mode on a host that already has
# teplanner-backend.service installed under systemd. Why: a manual
# `bash start.sh -d -s` spawns uvicorn outside systemd, collides on
# port 8000, and forces systemd into an infinite restart loop
# (6124× before triage on 2026-05-14). The intended prod path is
# `sudo systemctl restart teplanner-backend`. Force ($FORCE_DAEMON=1)
# overrides for the rare "I really know what I'm doing" case.
if [ "$DAEMON_MODE" = true ] && [ "$KILL_MODE" = false ] && [ "$RESTART_MODE" = false ]; then
    if command -v systemctl >/dev/null 2>&1 \
        && systemctl list-unit-files teplanner-backend.service 2>/dev/null \
              | grep -q "teplanner-backend.service"; then
        if [ "${FORCE_DAEMON:-0}" != "1" ]; then
            echo "${RED}refusing to start: teplanner-backend.service is installed${NC}" >&2
            echo "" >&2
            echo "On this host systemd owns the backend. Use:" >&2
            echo "  sudo systemctl restart teplanner-backend" >&2
            echo "" >&2
            echo "If you really want this script to fork its own uvicorn" >&2
            echo "(dev / debugging on a non-prod host):" >&2
            echo "  FORCE_DAEMON=1 bash start.sh -d -s" >&2
            exit 2
        fi
        echo "${YELLOW}WARN: FORCE_DAEMON=1 — running alongside systemd unit${NC}" >&2
    fi
fi

# Load .env file
load_env() {
    if [ -f "$SCRIPT_DIR/.env" ]; then
        export $(grep -v '^#' "$SCRIPT_DIR/.env" | grep -v '^$' | xargs)
    fi
}

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

# Wait for server to be ready
wait_for_server() {
    local max_attempts=30
    local attempt=1
    echo -e "${BLUE}Waiting for server to be ready...${NC}"

    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://127.0.0.1:$PORT/health" > /dev/null 2>&1; then
            echo -e "${GREEN}Server is ready${NC}"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done

    echo -e "${RED}Server failed to start${NC}"
    return 1
}

# Get Partner Token (client_credentials)
get_partner_token() {
    echo -e "${BLUE}[Tesla] Getting partner token...${NC}"

    local response=$(curl -s -X POST "$TESLA_AUTH_URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials" \
        -d "client_id=$TESLA_CLIENT_ID" \
        -d "client_secret=$TESLA_CLIENT_SECRET" \
        -d "scope=openid vehicle_device_data vehicle_cmds vehicle_charging_cmds" \
        -d "audience=$TESLA_FLEET_API")

    PARTNER_TOKEN=$(echo "$response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

    if [ -n "$PARTNER_TOKEN" ]; then
        echo -e "${GREEN}[Tesla] Partner token obtained${NC}"
        return 0
    else
        echo -e "${RED}[Tesla] Failed to get partner token${NC}"
        echo "$response"
        return 1
    fi
}

# Register Partner Account
register_partner() {
    echo -e "${BLUE}[Tesla] Checking partner registration...${NC}"

    local response=$(curl -s -X POST "$TESLA_FLEET_API/api/1/partner_accounts" \
        -H "Authorization: Bearer $PARTNER_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"domain": "api.teplanner.cloud"}')

    if echo "$response" | grep -q '"client_id"'; then
        echo -e "${GREEN}[Tesla] Partner account registered/verified${NC}"
        return 0
    elif echo "$response" | grep -q 'already registered'; then
        echo -e "${GREEN}[Tesla] Partner account already registered${NC}"
        return 0
    else
        echo -e "${YELLOW}[Tesla] Partner registration response: $response${NC}"
        return 0
    fi
}

# Refresh User Token
refresh_user_token() {
    if [ -z "$TESLA_REFRESH_TOKEN" ]; then
        echo -e "${YELLOW}[Tesla] No refresh token found, skipping token refresh${NC}"
        return 0
    fi

    echo -e "${BLUE}[Tesla] Refreshing user token...${NC}"

    local response=$(curl -s -X POST "$TESLA_AUTH_URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=refresh_token" \
        -d "client_id=$TESLA_CLIENT_ID" \
        -d "refresh_token=$TESLA_REFRESH_TOKEN")

    local new_access_token=$(echo "$response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    local new_refresh_token=$(echo "$response" | grep -o '"refresh_token":"[^"]*"' | cut -d'"' -f4)

    if [ -n "$new_access_token" ]; then
        echo -e "${GREEN}[Tesla] User token refreshed${NC}"

        # Update .env file
        sed -i "s|^TESLA_ACCESS_TOKEN=.*|TESLA_ACCESS_TOKEN=$new_access_token|" "$SCRIPT_DIR/.env"
        if [ -n "$new_refresh_token" ]; then
            sed -i "s|^TESLA_REFRESH_TOKEN=.*|TESLA_REFRESH_TOKEN=$new_refresh_token|" "$SCRIPT_DIR/.env"
        fi

        # Update environment variable
        export TESLA_ACCESS_TOKEN="$new_access_token"
        return 0
    else
        echo -e "${YELLOW}[Tesla] Token refresh failed, using existing token${NC}"
        return 0
    fi
}

# Test Vehicle Connection
test_vehicle_connection() {
    echo -e "${BLUE}[Tesla] Testing vehicle connection...${NC}"

    local response=$(curl -s -H "Authorization: Bearer $TESLA_ACCESS_TOKEN" \
        "$TESLA_FLEET_API/api/1/vehicles")

    if echo "$response" | grep -q '"vin"'; then
        local vehicle_name=$(echo "$response" | grep -o '"display_name":"[^"]*"' | head -1 | cut -d'"' -f4)
        local vehicle_state=$(echo "$response" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo -e "${GREEN}[Tesla] Vehicle connected: $vehicle_name ($vehicle_state)${NC}"
        return 0
    else
        echo -e "${YELLOW}[Tesla] Could not connect to vehicle${NC}"
        echo "$response"
        return 1
    fi
}

# Initialize Tesla API
init_tesla_api() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Tesla API Initialization${NC}"
    echo -e "${BLUE}========================================${NC}"

    load_env

    if [ -z "$TESLA_CLIENT_ID" ] || [ -z "$TESLA_CLIENT_SECRET" ]; then
        echo -e "${RED}[Tesla] Missing CLIENT_ID or CLIENT_SECRET in .env${NC}"
        return 1
    fi

    # Step 1: Get Partner Token
    if ! get_partner_token; then
        echo -e "${RED}[Tesla] Partner token failed, API may not work${NC}"
        return 1
    fi

    # Step 2: Register Partner Account
    register_partner

    # Step 3: Refresh User Token
    refresh_user_token

    # Step 4: Test Vehicle Connection
    if [ -n "$TESLA_ACCESS_TOKEN" ]; then
        test_vehicle_connection
    else
        echo -e "${YELLOW}[Tesla] No user token, skipping vehicle test${NC}"
        echo -e "${YELLOW}[Tesla] Visit https://api.teplanner.cloud/api/v1/auth/tesla/authorize to authorize${NC}"
    fi

    echo -e "${BLUE}========================================${NC}"
    echo ""
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

    # Wait for server to be ready
    if wait_for_server; then
        echo -e "${GREEN}Server started successfully${NC}"
        echo -e "  PID: $(cat $PID_FILE)"
        echo -e "  Log: $LOG_FILE"
        echo -e "  URL: http://$HOST:$PORT"

        # Initialize Tesla API
        if [ "$SKIP_TESLA" = false ]; then
            init_tesla_api
        fi

        echo ""
        echo "To stop: $0 -k"
        echo "To view logs: tail -f $LOG_FILE"
    else
        echo -e "${RED}Failed to start server${NC}"
        cat "$LOG_FILE"
        exit 1
    fi
else
    # For foreground mode, initialize Tesla first then start server
    if [ "$SKIP_TESLA" = false ]; then
        # Start server in background temporarily to initialize Tesla
        echo -e "${GREEN}Starting server for Tesla initialization...${NC}"
        nohup $UVICORN_CMD > "$LOG_FILE" 2>&1 &
        TEMP_PID=$!

        if wait_for_server; then
            init_tesla_api
        fi

        # Kill temporary server
        kill $TEMP_PID 2>/dev/null || true
        sleep 1
    fi

    # Run in foreground
    echo -e "${GREEN}Starting in foreground mode (Ctrl+C to stop)${NC}"
    echo ""
    exec $UVICORN_CMD
fi
