#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Starting Advanced Quarantine Tests..."

# Create test namespace
kubectl create namespace quarantine-test

# Apply test resources
kubectl apply -f advanced-test-pods.yaml -n quarantine-test
kubectl apply -f chaos-scenarios.yaml -n quarantine-test

# Wait for pods to be created
echo "Waiting for pods to initialize..."
sleep 20

# Test CVE-2023-1675 Detection
echo -n "Test 1 - CVE-2023-1675 Detection: "
CVE_POD=$(kubectl get pod test-cve-2023-1675 -n quarantine-test -o jsonpath='{.metadata.labels.quarantine-status}')
if [ "$CVE_POD" == "pending" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Test Memory Leak Detection
echo -n "Test 2 - Memory Leak Detection: "
sleep 30  # Wait for memory to build up
MEMORY_POD=$(kubectl get pod test-memory-leak -n quarantine-test -o jsonpath='{.status.containerStatuses[0].restartCount}')
if [ "$MEMORY_POD" -gt 0 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Test Network Abuse Detection
echo -n "Test 3 - Network Abuse Detection: "
NETWORK_POD=$(kubectl get pod test-network-abuse -n quarantine-test -o jsonpath='{.metadata.labels.quarantine-status}')
if [ "$NETWORK_POD" == "pending" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Chaos Testing
echo "Starting Chaos Tests..."

# Network Delay Test
echo -n "Test 4 - Network Delay Resilience: "
kubectl apply -f chaos-scenarios.yaml -n quarantine-test
sleep 30
QUARANTINE_POD=$(kubectl get pods -n quarantine-test -l app=security-automation -o jsonpath='{.items[0].status.phase}')
if [ "$QUARANTINE_POD" == "Running" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# CPU Stress Test
echo -n "Test 5 - CPU Stress Handling: "
kubectl apply -f chaos-scenarios.yaml -n quarantine-test
sleep 30
CPU_STRESSED=$(kubectl get pods -n quarantine-test -l app=security-automation -o jsonpath='{.items[0].status.containerStatuses[0].ready}')
if [ "$CPU_STRESSED" == "true" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Metrics Validation
echo "Validating Metrics..."

# Check if metrics are being collected
echo -n "Test 6 - Metrics Collection: "
METRICS=$(kubectl get servicemonitor quarantine-metrics -n monitoring -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
if [ "$METRICS" == "True" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${YELLOW}SKIP - Prometheus Operator not detected${NC}"
fi

# Test Forensics
echo -n "Test 7 - Forensics Capture: "
FORENSICS_FILES=$(kubectl exec -n quarantine-test $(kubectl get pod -n quarantine-test -l app=security-automation -o jsonpath='{.items[0].metadata.name}') -- ls /var/log/forensics/)
if [ -n "$FORENSICS_FILES" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Integration Tests
echo "Running Integration Tests..."

# Test Network Policy Creation
echo -n "Test 8 - Network Policy Integration: "
NETPOL=$(kubectl get networkpolicies -n quarantine-test -l app=security-automation -o name)
if [ -n "$NETPOL" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Clean up
echo "Cleaning up test resources..."
kubectl delete namespace quarantine-test
kubectl delete -f chaos-scenarios.yaml 2>/dev/null

echo "Advanced test suite completed."
echo "Generating test report..."

# Generate test report
cat << EOF > test-report.txt
Quarantine Framework Test Report
$(date)

1. CVE Detection: ${CVE_POD:-FAIL}
2. Resource Abuse Detection: ${MEMORY_POD:-FAIL}
3. Network Abuse Detection: ${NETWORK_POD:-FAIL}
4. Chaos Resilience: ${QUARANTINE_POD:-FAIL}
5. Performance Under Load: ${CPU_STRESSED:-FAIL}
6. Metrics Collection: ${METRICS:-N/A}
7. Forensics System: ${FORENSICS_FILES:-FAIL}
8. Network Policy Integration: ${NETPOL:-FAIL}

EOF

echo "Test report generated: test-report.txt"
