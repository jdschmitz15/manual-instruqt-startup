#!/bin/bash

usage() {
  echo "Usage: $0 -f <pceFqdn> -P <pcePort> -u <apiName> -s <apiSecret> -o <orgId>"
  echo "  -f  PCE FQDN"
  echo "  -P  PCE Port"
  echo "  -u  API Username"
  echo "  -s  API Secret"
  echo "  -o  Org ID"
  exit 1
}

while getopts "f:P:u:s:o:" opt; do
  case $opt in
    f) pceFqdn="$OPTARG" ;;
    P) pcePort="$OPTARG" ;;
    u) apiName="$OPTARG" ;;
    s) apiSecret="$OPTARG" ;;
    o) orgId="$OPTARG" ;;
    *) usage ;;
  esac
done

# Check required arguments
if [[ -z "$pceFqdn" || -z "$pcePort" || -z "$apiName" || -z "$apiSecret" || -z "$orgId" ]]; then
  usage
fi

# Run in startup/teardown directory
cd ~/manual-instruqt-startup


# Generate Pairing Keys
echo -e "\n### Generating Pairing Keys ###"
./workloader get-pk --profile Default-Servers --create --ven-type server -f server_pp
./workloader get-pk --profile Default-Endpoints --create --ven-type endpoint -f endpoint_pp

# Activate VENSim
echo -e "\n### Activating VENSim ###"
SERVER_PK=$(cat server_pp)
ENDPOINT_PK=$(cat endpoint_pp)

./vensim activate -c ~/vensim-templates/standard-demo/vens.csv -p ~/vensim-templates/standard-demo/processes.csv -m "$pceFqdn:$pcePort" -a "$SERVER_PK" -e "$ENDPOINT_PK"

./vensim post-traffic -c ~/vensim-templates/standard-demo/vens.csv -t ~/vensim-templates/standard-demo/traffic.csv -d "today"

# Create and Import Resources
echo -e "\n### Creating and Importing Resources ###"
./workloader label-dimension-import ~/vensim-templates/standard-demo/labeldimensions.csv --update-pce --no-prompt
./workloader wkld-import ~/vensim-templates/standard-demo/wklds.csv --umwl --allow-enforcement-changes --update-pce --no-prompt
./workloader svc-import ~/vensim-templates/standard-demo/svcs.csv --update-pce --provision --no-prompt 
./workloader svc-import ~/vensim-templates/svcs_meta.csv --meta --update-pce --no-prompt --provision
./workloader ipl-import ~/vensim-templates/standard-demo/iplists.csv --update-pce --no-prompt --provision
./workloader ruleset-import ~/vensim-templates/standard-demo/rulesets.csv --update-pce --no-prompt --provision
./workloader adgroup-import ~/vensim-templates/standard-demo/adgroups.csv --update-pce --no-prompt
./workloader rule-import ~/vensim-templates/standard-demo/rules.csv --update-pce --no-prompt --provision


echo -e "\n### Script Execution Completed Successfully ###"

# Crontab setup
echo -e "\n### Setting up Crontab ###"

if [[ $EUID -ne 0 ]]; then
  echo "This script requires root privileges to set crontab for another user. Run with sudo if needed."
  exit 1
fi

CRON_CONFIG=$(cat <<'EOF'
# Make sure vensim is in path
PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/centos/.local/bin:/home/centos/bin

# Make sure vensim is in path
PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/centos/.local/bin:/home/centos/bin

# Set variables
TARGET_DIR=/root
PCE=poc3.illum.io:443
WORKLOAD_FILE=~/vensim-templates/standard-demo/vens.csv
TRAFFIC_FILE=~/vensim-templates/standard-demo/traffic.csv
PROCESS_FILE=~/vensim-templates/standard-demo/processes.csv

# Update workload running processes once a day at 6 AM
0 6 * * * cd $TARGET_DIR && ./vensim update-processes -c $WORKLOAD_FILE -p $PROCESS_FILE >/dev/null 2>&1

# Post traffic every 10 minutes
*/10 * * * * cd $TARGET_DIR && ./vensim post-traffic -c $WORKLOAD_FILE -t $TRAFFIC_FILE -d today >/dev/null 2>&1

# Heartbeat every 5 minutes
*/5 * * * * cd $TARGET_DIR && ./vensim heartbeat -c $WORKLOAD_FILE >/dev/null 2>&1

# Mimic event service by getting policy every 15 seconds.
* * * * * cd $TARGET_DIR && ./vensim get-policy -c $WORKLOAD_FILE >/dev/null 2>&1
* * * * * sleep 15 && cd $TARGET_DIR && ./vensim get-policy -c $WORKLOAD_FILE >/dev/null 2>&1
* * * * * sleep 30 && cd $TARGET_DIR && ./vensim get-policy -c $WORKLOAD_FILE >/dev/null 2>&1
* * * * * sleep 45 && cd $TARGET_DIR && ./vensim get-policy -c $WORKLOAD_FILE >/dev/null 2>&1

# Remove the vensim log every hour
0 * * * * cd $TARGET_DIR && rm -f vensim.log
EOF
)

echo "$CRON_CONFIG" | crontab -

echo "Crontab applied successfully!"
