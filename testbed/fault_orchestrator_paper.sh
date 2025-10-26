#!/bin/bash
# Initialize random seed
RANDOM=$$$(date +%s)

# Environment configuration
export MYSQL_POD="mysql-566949489-qv746"
export NAMESPACE="monitoring"

# Clean up old data
rm -f data/fault_timeline.csv
mkdir -p data/{logs,metrics}

# Training phase - fixed sequence (20 minutes/1200 seconds)
TRAINING_PLAN=(
    # Type       Parameters         Duration(seconds)  Interval(seconds) Count
    "recovery   120"                               # Recovery period
    "qps        100 30 60 2"                      # Abnormal workload
    "cpu        10 95 30 60 2"                    # CPU saturation
    "mem        6 30 60 2"                        # Memory saturation
    # Recovery after training phase
    "recovery   120"                      # Recovery period
)

# Execute training phase
echo "=== Starting Training Phase ==="
START=$(gdate +%s.%3N 2>/dev/null)
seconds_part=$(echo "$START" | cut -d. -f1)
ms_part=$(echo "$START" | cut -d. -f2)
readable_date=$(gdate -r "$seconds_part" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
if [ -z "$readable_date" ]; then
    readable_date=$(date -r "$seconds_part" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || 
        date -j -f "%s" "$seconds_part" "+%Y-%m-%d %H:%M:%S")
fi
echo "TRAINING-PHASE $START ${readable_date}.${ms_part}" >> data/fault_timeline.csv

for plan in "${TRAINING_PLAN[@]}"; do
    read -r fault_type params <<< "$plan"
    case $fault_type in
        recovery)
            echo "[Recovery] Duration: ${params} seconds"
            sleep $params
            ;;
        qps)
            echo "[Workload] Parameters: ${params}"
            ./inject_QPS_fault.sh $params
            ;;
        cpu)
            echo "[CPU] Parameters: ${params}"
            ./inject_cpu_fault.sh $params
            ;;
        mem)
            echo "[Memory] Parameters: ${params}"
            ./inject_mem_fault.sh $params
            ;;
    esac
done

# Testing phase - random faults (40 minutes/2400 seconds)
TESTING_DURATION=2400  # 40 minutes
TESTING_START=$(date +%s)

# Execute testing phase - completely random
echo "=== Starting Testing Phase ==="
START=$(gdate +%s.%3N 2>/dev/null)
seconds_part=$(echo "$START" | cut -d. -f1)
ms_part=$(echo "$START" | cut -d. -f2)
readable_date=$(gdate -r "$seconds_part" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
if [ -z "$readable_date" ]; then
    readable_date=$(date -r "$seconds_part" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || 
        date -j -f "%s" "$seconds_part" "+%Y-%m-%d %H:%M:%S")
fi
echo "TESTING-PHASE $START ${readable_date}.${ms_part}" >> data/fault_timeline.csv

while [ $(($(date +%s) - TESTING_START)) -lt $TESTING_DURATION ]; do
    # Randomly select fault type
    FAULT_TYPES=("qps" "cpu" "mem")
    SELECTED_FAULT=${FAULT_TYPES[$RANDOM % 3]}
    
    # Random parameters
    case $SELECTED_FAULT in
        qps)
            # TERMINALS=$((80 + RANDOM % 20))  # 80-100 terminals
            # DURATION=$((15 + RANDOM % 45))     # 15-60 seconds
            TERMINALS=100
            DURATION=30
            PARAMS="$TERMINALS $DURATION"
            ;;
        cpu)
            # WORKERS=$((5 + RANDOM % 10))       # 5-15 workers
            # USAGE=$((85 + RANDOM % 15))        # 85-99% utilization
            # DURATION=$((30 + RANDOM % 30))     # 30-60 seconds
            WORKERS=10
            USAGE=95
            DURATION=30
            PARAMS="$WORKERS $USAGE $DURATION"
            ;;
        mem)
            # WORKERS=$((4 + RANDOM % 8))        # 4-12 workers
            # DURATION=$((30 + RANDOM % 30))     # 30-60 seconds
            WORKERS=6
            DURATION=30
            PARAMS="$WORKERS $DURATION"
            ;;
    esac
    
    # Random interval (60-180 seconds)
    WAIT_TIME=$((60 + RANDOM % 120))
    
    # Inject fault
    echo "[Testing] Fault type: ${SELECTED_FAULT} Parameters: ${PARAMS}"
    case $SELECTED_FAULT in
        qps) ./inject_QPS_fault.sh $PARAMS $WAIT_TIME 1 ;;
        cpu) ./inject_cpu_fault.sh $PARAMS $WAIT_TIME 1 ;;
        mem) ./inject_mem_fault.sh $PARAMS $WAIT_TIME 1 ;;
    esac
done

# Final recovery
echo "=== Final Recovery ==="
sleep 120  # 2 minute recovery period

END=$(gdate +%s.%3N 2>/dev/null)
seconds_part=$(echo "$END" | cut -d. -f1)
ms_part=$(echo "$END" | cut -d. -f2)
readable_date=$(gdate -r "$seconds_part" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
if [ -z "$readable_date" ]; then
    readable_date=$(date -r "$seconds_part" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || 
        date -j -f "%s" "$seconds_part" "+%Y-%m-%d %H:%M:%S")
fi
echo "END $END ${readable_date}.${ms_part}" >> data/fault_timeline.csv

# Data packaging
TS=$(date +%Y%m%d_%H%M%S)
tar czf results/fault_injection_${TS}.tar.gz data/