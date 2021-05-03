#!/bin/bash -f

# Global Variables 
getAllSAKeys=/home/robertoruizroxas/task5/demo/output/getSAKeys.txt
getSAKeysActive30days=/home/robertoruizroxas/task5/demo/output/raw_getSAKeysActive30days.txt
processed_SAKeysActive30days=/home/robertoruizroxas/task5/demo/output/processed_SAKeysActive30days.txt
getSAKeysActive30days=/home/robertoruizroxas/task5/demo/output/raw_getSAKeysActive30days.txt
removeMatchingActiveSAKeysFromgetAllSAKeys=/home/robertoruizroxas/task5/demo/output/removeMatchingActiveSAKeysFromgetAllSAKeys

# Global Variables for service account api
token="$(gcloud auth application-default print-access-token)"
metric_type='"iam.googleapis.com%2Fservice_account%2Fkey%2Fauthn_events_count"'
end_time=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
start_time=`date --date="-30 days" --rfc-3339=date | awk '{print $0"T12:00:00Z"}'`

# Cleanup previously generated files

if test -f "$getSAKeysActive30days"; then
    rm $getSAKeysActive30days
fi
if test -f "$processed_SAKeysActive30days"; then
    rm $processed_SAKeysActive30days
fi
if test -f "$getAllSAKeys"; then
    rm $getAllSAKeys
fi
if test -f "$processed_SAKeysActive30days"; then
    rm $getSAKeysActive30days
fi

function fn_dormantsakeys() {

echo "Gathering all avialable service accounts keys in this GCP enviroment."

for PROJECT in $(\
  gcloud projects list \
  --format="value(projectId)")
do
  for ACCOUNT in $(\
    gcloud iam service-accounts list \
    --project=${PROJECT} \
    --format="value(email)")
  do
    gcloud iam service-accounts keys list --iam-account=${ACCOUNT} --project=${PROJECT} --managed-by user --format="json" | jq -r '.[] | [.name] | @csv'  | sed 's/"//g' | sed 's/\//\t/g' | awk '{print $2,$4,$6}' >> $getAllSAKeys
  done
done
# --- #
echo "sleeping for 3 seconds."
echo "Gathering all service account keys that's been active for 30 days."

for projectname in `gcloud projects list --format="json" | jq -r '.[].projectId'`; do
  curl \
      -sS --header "Authorization: Bearer $token" \
      "https://monitoring.googleapis.com/v3/projects/$projectname/timeSeries?filter=metric.type%3D%22iam.googleapis.com%2Fservice_account%2Fkey%2Fauthn_events_count%22&interval.endTime=$end_time&interval.startTime=$start_time"  | grep 'key_id' | sed 's/"//g' | sed 's/,//g' | awk '{print $2}' >> $getSAKeysActive30days
done
# --- #
echo "sleeping for 3 seconds."
echo "Generating dormant service account keys list now."

/bin/cat $getSAKeysActive30days | sort -n | uniq >> $processed_SAKeysActive30days
/usr/bin/awk '{print VAR$1VAR1,VAR2}' VAR="sed -i '/" VAR1="/d'" VAR2="'$getAllSAKeys'" < $processed_SAKeysActive30days | sh
#/usr/bin/awk '{print VAR$1VAR1,VAR2}' VAR="sed -i '/" VAR1="/d'" VAR2="'$getAllSAKeys'" < $processed_SAKeysActive30days 
sleep 3;
echo "Removed 30 Days Active Service Accounts Keys in: " $getAllSAKeys
echo $getAllSAKeys "should only have Service Accounts Keys that's dormant for 30 days."

}

fn_dormantsakeys