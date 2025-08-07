package kubernetes.quarantine

# Test policy for quarantine criteria
test_should_quarantine_no_scan {
    pod := {
        "metadata": {
            "name": "test-pod",
            "labels": {}
        }
    }
    should_quarantine(pod)
}

test_should_quarantine_pending_status {
    pod := {
        "metadata": {
            "name": "test-pod",
            "labels": {
                "quarantine-status": "pending"
            }
        }
    }
    should_quarantine(pod)
}

test_should_quarantine_high_restarts {
    pod := {
        "metadata": {
            "name": "test-pod"
        },
        "status": {
            "containerStatuses": [{
                "restartCount": 6
            }]
        }
    }
    should_quarantine(pod)
}

test_should_not_quarantine_cleared {
    pod := {
        "metadata": {
            "name": "test-pod",
            "labels": {
                "security-scan": "cleared"
            }
        },
        "status": {
            "containerStatuses": [{
                "restartCount": 0
            }]
        }
    }
    not should_quarantine(pod)
}

# Main policy rules
should_quarantine(pod) {
    not pod.metadata.labels["security-scan"] == "cleared"
}

should_quarantine(pod) {
    pod.metadata.labels["quarantine-status"] == "pending"
}

should_quarantine(pod) {
    some i
    pod.status.containerStatuses[i].restartCount > 5
}
