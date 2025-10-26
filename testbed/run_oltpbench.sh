#!/bin/bash
# run_oltpbench.sh

# Configuration parameters
BENCHMARK=${BENCHMARK:-"tpcc"}
CONFIG_FILE=${CONFIG_FILE:-"config/tpcc_config_mysql.xml"}
INTERVAL_MS=${INTERVAL_MS:-300}
EXPORTER_PORT=${EXPORTER_PORT:-8088}
TEMP_FILE="oltpbench_metrics_${EXPORTER_PORT}.tmp"
BASE_LOG_NAME="oltpbench_$(date +%Y%m%d_%H%M%S)"
EXPORTER_LOG="exporter_${EXPORTER_PORT}.log"

# Cleanup function
cleanup() {
    echo "Performing cleanup..."
    # Stop OLTPBench processes
    pkill -f "oltpbenchmark" 2>/dev/null
    # Stop exporter processes
    pkill -f "python3.*oltpbench_exporter.py" 2>/dev/null
    # Stop all grep processes
    pkill -f "grep.*Metrics:" 2>/dev/null
    # Remove temporary files
    rm -f "$TEMP_FILE" 2>/dev/null
    echo "Cleanup completed"
}

# Port cleanup function
clean_port() {
    local port=$1
    echo "Checking port ${port} occupancy..."
    # Use lsof to check port
    if command -v lsof >/dev/null; then
        pid_list=$(lsof -t -i :${port})
        if [ -n "$pid_list" ]; then
            echo "Found processes occupying port ${port}:"
            ps -p $pid_list
            echo "Terminating occupying processes..."
            kill -9 $pid_list
            sleep 1
        fi
    fi
    # Use netstat to check port (macOS backup)
    if command -v netstat >/dev/null; then
        if netstat -an | grep ".${port} " | grep LISTEN; then
            echo "Port ${port} is still occupied, attempting forced release..."
            # macOS specific command
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sudo lsof -i tcp:${port} | grep LISTEN | awk '{print $2}' | xargs kill -9
            fi
        fi
    fi
    # Final check
    if command -v lsof >/dev/null; then
        if lsof -i :${port} >/dev/null; then
            echo "Warning: Failed to release port ${port}"
            return 1
        else
            echo "Port ${port} has been released"
            return 0
        fi
    fi
    return 0
}

# Register exit handler
trap cleanup EXIT INT TERM

# Pre-start cleanup
cleanup
clean_port $EXPORTER_PORT

# Create temporary file
echo "Creating temporary file: $TEMP_FILE"
touch "$TEMP_FILE"

# Start metrics exporter
echo "Starting metrics exporter (port: $EXPORTER_PORT)..."
echo "Executing command: tail -f $TEMP_FILE | python3 oltpbench_exporter.py $EXPORTER_PORT > $EXPORTER_LOG 2>&1 &"

# Start exporter
tail -f "$TEMP_FILE" | python3 oltpbench_exporter.py "$EXPORTER_PORT" > "$EXPORTER_LOG" 2>&1 &
EXPORTER_PID=$!
echo "Exporter PID: $EXPORTER_PID"

# Wait for exporter to start
echo "Waiting for exporter initialization..."
sleep 5

# Check process status
if ! ps -p $EXPORTER_PID > /dev/null; then
    echo "Exporter process has exited! Check log:"
    cat "$EXPORTER_LOG"
    exit 1
fi

# Verify exporter is listening on the port
if ! lsof -i :$EXPORTER_PORT -P -n | grep LISTEN > /dev/null; then
    echo "Exporter is not listening on port $EXPORTER_PORT!"
    echo "Exporter log:"
    cat "$EXPORTER_LOG"
    exit 1
fi

# Perform health check
echo "Performing health check..."
HEALTH_RESPONSE=$(curl -s --max-time 2 "http://localhost:$EXPORTER_PORT/health")
if [ $? -ne 0 ]; then
    echo "Cannot connect to health check endpoint"
    echo "Exporter log:"
    cat "$EXPORTER_LOG"
    exit 1
fi

echo "Health check response: $HEALTH_RESPONSE"

# Start OLTPBench
echo "Starting OLTPBench test..."
{
    ./oltpbenchmark \
        -b "$BENCHMARK" \
        -c "$CONFIG_FILE" \
        --execute=true \
        -s 1 \
        -im "$INTERVAL_MS" \
        -o "$BASE_LOG_NAME" 2>&1 | \
        tee "${BASE_LOG_NAME}.log" | \
        grep --line-buffered "Metrics:" >> "$TEMP_FILE"
} &
OLTP_PID=$!

echo "OLTPBench PID: $OLTP_PID, Exporter PID: $EXPORTER_PID"
echo "OLTPBench monitoring log: tail -f '${BASE_LOG_NAME}.log'"
echo "Exporter log: tail -f '$EXPORTER_LOG'"
echo "Metrics input: tail -f '$TEMP_FILE'"

# Wait for test completion
wait "$OLTP_PID"
EXIT_STATUS=$?

if [ $EXIT_STATUS -eq 0 ]; then
    echo "Test completed successfully"
    echo "Result files: results/${BASE_LOG_NAME}.{csv,res}"
else
    echo "Test exited abnormally (status: $EXIT_STATUS)"
fi

# Wait for exporter to process remaining data
sleep 2

exit $EXIT_STATUS