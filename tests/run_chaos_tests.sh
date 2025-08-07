#!/bin/bash

# Setup logging
LOGFILE="/var/log/chaos-testing.log"
echo "Starting chaos testing at $(date)" >> $LOGFILE

# Test scenarios array
declare -a scenarios=(
    "pod-failure-chaos"
    "network-partition-chaos"
    "io-delay-chaos"
    "cpu-stress-chaos"
    "dns-chaos"
)

# Function to check quarantine system response
check_quarantine_response() {
    local scenario=$1
    local start_time=$(date +%s)
    
    echo "Testing scenario: $scenario at $(date)" >> $LOGFILE
    
    # Apply chaos scenario
    kubectl apply -f chaos/$scenario.yaml
    sleep 30
    
    # Check if quarantine system detected and responded
    local quarantined_pods=$(kubectl get pods -l quarantine-status=active --all-namespaces -o json | jq '.items | length')
    local response_time=$(($(date +%s) - start_time))
    
    echo "Response time for $scenario: ${response_time}s" >> $LOGFILE
    echo "Number of quarantined pods: $quarantined_pods" >> $LOGFILE
    
    # Clean up
    kubectl delete -f chaos/$scenario.yaml
    sleep 10
}

# Function to validate system stability
check_system_stability() {
    local api_response=$(kubectl get --raw /healthz)
    if [ "$api_response" != "ok" ]; then
        echo "WARNING: API server health check failed!" >> $LOGFILE
        return 1
    fi
    
    local node_status=$(kubectl get nodes -o json | jq -r '.items[].status.conditions[] | select(.type=="Ready") | .status')
    if [[ $node_status == *"False"* ]]; then
        echo "WARNING: Some nodes are not ready!" >> $LOGFILE
        return 1
    fi
    
    return 0
}

# Main test execution
echo "Starting chaos test suite" >> $LOGFILE

for scenario in "${scenarios[@]}"; do
    # Check system stability before test
    if ! check_system_stability; then
        echo "System unstable, skipping $scenario" >> $LOGFILE
        continue
    fi
    
    # Run test scenario
    check_quarantine_response $scenario
    
    # Allow system to stabilize
    sleep 30
    
    # Verify system recovery
    if ! check_system_stability; then
        echo "System failed to recover after $scenario" >> $LOGFILE
    else
        echo "System successfully recovered from $scenario" >> $LOGFILE
    fi
done

echo "Chaos testing completed at $(date)" >> $LOGFILE

# Generate test report
cat << EOF > chaos-test-report.json
{
    "testTimestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "scenarioResults": $(kubectl get events --all-namespaces -o json | jq -r '[.items[] | select(.reason=="ChaosInjection")]'),
    "systemStability": {
        "apiServer": "$(kubectl get --raw /healthz)",
        "nodeStatus": $(kubectl get nodes -o json | jq '.items[].status.conditions[] | select(.type=="Ready")')
    }
}
EOF
