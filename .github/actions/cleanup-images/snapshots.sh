#!/usr/bin/env bash

if [[ -z $HCLOUD_TOKEN ]]; then
  echo "Please set the HCLOUD_TOKEN environment variable"
  exit 1
fi

snapshot_names=$(hcloud image list -o noheader -o columns=description -t snapshot | sort -u)

for snapshot_name in $snapshot_names; do
  snapshots=$(hcloud image list -s created -o noheader -o columns=id,description -t snapshot | grep "$snapshot_name")

  if [[ $(echo "$snapshots" | wc -l) -gt 1 ]]; then
    echo "$snapshots"
    delete_images_ids=$(echo "$snapshots" | awk '{print $1}' | tail -n +2)
    for image_id in $delete_images_ids; do
      echo "Deleting image with id $image_id"
      hcloud image delete "$image_id"
    done
  fi
done
