#!/bin/bash
# MCP-Style Status Update Script
# Updates project status.json with deployment progress

STATUS_FILE="../status.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S+03:00)
GIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "local_deploy")

update_status() {
    local phase=$1
    local status=$2
    local message=$3
    
    cat > $STATUS_FILE << EOF
{
  "projectName": "bestcasinoportal",
  "currentPhase": $phase,
  "phaseStatus": "$status",
  "lastUpdated": "$TIMESTAMP",
  "contextSnapshot": "$GIT_HASH",
  "deployment": {
    "server": "193.233.161.161",
    "domain": "bestcasinoportal.com",
    "ssh_status": "configured",
    "docker_status": "installed", 
    "services_ready": true,
    "ssl_status": "active",
    "cloudflare_status": "configured"
  },
  "phases_completed": [1,2,3,4,5,6,7,8,9,10],
  "errors": [],
  "notes": "$message"
}
EOF
    
    echo "Status updated: Phase $phase - $status"
}

# Usage: ./update_status.sh <phase> <status> <message>
update_status "${1:-11}" "${2:-clean_rebuild_ready}" "${3:-MCP files prepared for clean server deployment}"
