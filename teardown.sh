#!/bin/bash
 
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

#Run in startup/teardown directory
cd ~/manual-instruqt-startup

echo -e "\n### Starting Deletion Operations ###"

#--- unpair vens-----

workloader ven-export --excl-containerized --headers wkld_href --output-file /tmp/unpair_vens.csv
if [[ -f /tmp/unpair_vens.csv ]]; then
  sed -i 's/workloads/vens/g' /tmp/unpair_vens.csv
  workloader unpair --href-file /tmp/unpair_vens.csv --include-online --update-pce --no-prompt
fi

#--- dd pairing profile ------
workloader pairing-profile-export --output-file /tmp/delete_pp.csv
if [[ -f /tmp/delete_pp.csv ]]; then
  workloader delete /tmp/delete_pp.csv --header href --update-pce --no-prompt --provision
fi

#----dd ruleset -------
workloader ruleset-export --output-file /tmp/delete_ruleset.csv
if [[ -f /tmp/delete_ruleset.csv ]]; then
  workloader delete /tmp/delete_ruleset.csv --header href --update-pce --no-prompt --provision --continue-on-error
fi

#--- dd deny rules -----
workloader deny-rule-export --output-file /tmp/delete_deny.csv 
if [[ -f /tmp/delete_deny.csv ]]; then
   workloader delete /tmp/delete_deny.csv --header href --update-pce --no-prompt --provision --continue-on-error
fi
#---dd lbg-----
workloader labelgroup-export --output-file /tmp/delete_lbg.csv
if [[ -f /tmp/delete_lbg.csv ]]; then
   workloader delete /tmp/delete_lbg.csv --header href --update-pce --no-prompt --provision --continue-on-error
fi

#--dd umwl-----
workloader wkld-export --output-file /tmp/delete_umwl.csv 
if [[ -f /tmp/delete_umwl.csv ]]; then
   workloader delete /tmp/delete_umwl.csv --header href --update-pce --no-prompt --provision --continue-on-error
fi

#--dd svc-----
workloader svc-export --compressed --output-file /tmp/delete_svc.csv 
if [[ -f /tmp/delete_svc.csv ]]; then
   workloader delete /tmp/delete_svc.csv --header href --update-pce --no-prompt --provision --continue-on-error
fi

#--dd ipl-----
workloader ipl-export --output-file /tmp/delete_ipl.csv 
if [[ -f /tmp/delete_ipl.csv ]]; then
   workloader delete /tmp/delete_ipl.csv --header href --update-pce --no-prompt --provision --continue-on-error
fi

#---dd label---
workloader label-export --output-file /tmp/delete_labels.csv 
if [[ -f /tmp/delete_labels.csv ]]; then
   workloader delete /tmp/delete_labels.csv --header href --update-pce --no-prompt --provision
fi

#--dd label dimension----
workloader label-dimension-export --output-file /tmp/delete_label_dimension.csv 
if [[ -f /tmp/delete_label_dimension.csv ]]; then
   workloader delete /tmp/delete_label_dimension.csv --header href --update-pce --no-prompt --provision
fi

#--dd ad-----
workloader adgroup-export --output-file /tmp/delete_ad.csv 
if [[ -f /tmp/delete_ad.csv ]]; then
   workloader delete /tmp/delete_ad.csv --header href --update-pce --no-prompt --provision --continue-on-error
fi

echo -e "\n### Deletion Operations Completed ###"

