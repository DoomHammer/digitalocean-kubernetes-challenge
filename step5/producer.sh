#!/bin/sh
TOPIC=$1
shift
VALUE=$@

curl -X POST "http://localhost:8080/topics/${TOPIC}" \
     -H 'Content-Type: application/vnd.kafka.json.v2+json' \
     -d '{ "records": [ { "value": "'"$VALUE"'" } ] }'
