#!/bin/sh
curl -X POST http://localhost:8080/consumers/my-group \
     -H 'Content-Type: application/vnd.kafka.v2+json' \
     -d '{
           "name": "my-consumer",
           "auto.offset.reset": "earliest",
           "format": "json",
           "enable.auto.commit": true,
           "fetch.min.bytes": 512,
           "consumer.request.timeout.ms": 30000
         }'
