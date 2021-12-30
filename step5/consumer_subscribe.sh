#!/bin/sh
TOPIC=$1

curl -X POST http://localhost:8080/consumers/my-group/instances/my-consumer/subscription \
     -H 'Content-Type: application/vnd.kafka.v2+json' \
     -d '{
           "topics": [
             "'"$TOPIC"'"
           ]
         }'
