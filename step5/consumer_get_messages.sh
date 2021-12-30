#!/bin/sh
curl -X GET http://localhost:8080/consumers/my-group/instances/my-consumer/records \
     -H 'Accept: application/vnd.kafka.json.v2+json'
