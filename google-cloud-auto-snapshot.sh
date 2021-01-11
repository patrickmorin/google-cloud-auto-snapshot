#!/bin/bash

if [ -z "${DAYS_RETENTION}" ]; then
  # Default to 60 days
  DAYS_RETENTION=60
  GDPR_DAYS_RETENTION=180
fi

# Author: Patrick Morin, Esokia
# authentification with service account
gcloud auth activate-service-account --key-file=/path/to/serviceaccount.json
# loop through all disks within this project  and create a snapshot
gcloud compute disks list --format='value(name,zone)'| while read -r DISK_NAME ZONE; do
  gcloud compute disks snapshot "${DISK_NAME}" --snapshot-names autogcs-"${DISK_NAME:0:31}"-"$(date '+%Y-%m-%d-%s')" --zone "${ZONE}"
done
#
# snapshots are incremental and dont need to be deleted, deleting snapshots will merge snapshots, so deleting doesn't loose anything
# having too many snapshots is unwiedly so this script deletes them after 60 days
#
if [[ $(uname) == "Linux" ]]; then
  from_date=$(date -d "-${DAYS_RETENTION} days" "+%Y-%m-%d")
  gdpr_from_date=$(date -d "-${GDPR_DAYS_RETENTION} days" "+%Y-%m-%d")
else
  from_date=$(date -v -${DAYS_RETENTION}d "+%Y-%m-%d")
  gdpr_from_date=$(date -v -${GDPR_DAYS_RETENTION}d "+%Y-%m-%d")
fi
# Standard process
gcloud compute snapshots list --filter="creationTimestamp<${from_date} AND name~'autogcs.*'" --uri | while read SNAPSHOT_URI; do
   gcloud compute snapshots delete "${SNAPSHOT_URI}"  --quiet
done
# GDPR process
gcloud compute snapshots list --filter="creationTimestamp<${gdpr_from_date} AND name~'autogcs(.*)(name1|name2)(.*)'" --uri | while read SNAPSHOT_URI; do
   gcloud compute snapshots delete "${SNAPSHOT_URI}"  --quiet
done
#