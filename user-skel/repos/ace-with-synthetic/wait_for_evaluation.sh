#!/bin/sh

set -euo pipefail

POLL_INTERVAL=10

echo "Waiting for evaluation result in context $1"

while : ; do
  echo "Retrieving events..."

  EVENTS=$(curl -s -X GET "$KEPTN_ENDPOINT/api/mongodb-datastore/event?keptnContext=$1&type=sh.keptn.event.$DT_RELEASE_STAGE.evaluation.finished&pageSize=20" -H "accept: application/json" -H "x-token: $KEPTN_API_TOKEN")
  NUMBER_OF_EVENT=$(echo $EVENTS | jq -r ".events | length")
  
  echo "Number of events retrieved: $NUMBER_OF_EVENT"

  if [ "$NUMBER_OF_EVENT" -ne 0 ]; then
    break
  fi

  echo "Sleeping $POLL_INTERVAL seconds..."
  sleep $POLL_INTERVAL
done

EVALUATION_RESULT=$(echo $EVENTS | jq -r ".events[0].data.result")

echo "Retrieved evaluation result: $EVALUATION_RESULT"

if [ "$EVALUATION_RESULT" == "pass" ]; then
  exit 0
fi

exit 1
