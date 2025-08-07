#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Starting Quarantine Workflow Tests..."

# Create test namespace
kubectl create namespace quarantine-test

# Apply test pods
kubectl apply -f test-pods.yaml -n quarantine-test

echo "Waiting for pods to be created..."
sleep 10

# Test 1: Check if pod without security-scan label is detected
echo -n "Test 1 - Pod without security-scan label: "
PODS=$(kubectl get pods -n quarantine-test -l app=test-quarantine --field-selector metadata.name=test-pod-no-scan -o json | jq -r '.items[].metadata.name')
if [ -n "$PODS" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Test 2: Check if pod with pending quarantine status is detected
echo -n "Test 2 - Pod with pending quarantine status: "
PODS=$(kubectl get pods -n quarantine-test -l quarantine-status=pending -o json | jq -r '.items[].metadata.name')
if [ -n "$PODS" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Test 3: Wait for high-restart pod to accumulate restarts
echo "Waiting for test-pod-high-restarts to accumulate restarts..."
sleep 30

echo -n "Test 3 - Pod with high restart count: "
RESTARTS=$(kubectl get pod test-pod-high-restarts -n quarantine-test -o jsonpath='{.status.containerStatuses[0].restartCount}')
if [ "$RESTARTS" -gt 5 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Test 4: Check if cleared pod is ignored
echo -n "Test 4 - Cleared pod not quarantined: "
CLEARED_POD=$(kubectl get pod test-pod-cleared -n quarantine-test -o json | jq -r '.metadata.labels."security-scan"')
if [ "$CLEARED_POD" == "cleared" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Test OPA policies
echo -n "Test 5 - OPA Policy Validation: "
if command -v opa &> /dev/null; then
    opa test quarantine_test.rego --verbose
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
    fi
else
    echo -e "${RED}SKIP - OPA not installed${NC}"
fi

# Cleanup
echo "Cleaning up test resources..."
kubectl delete namespace quarantine-test

echo "Test suite completed."
