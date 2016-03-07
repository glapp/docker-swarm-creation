#!/bin/bash
echo "Starting script..."
docker-machine rm -f kvstore-DO
docker-machine rm -f DO-master
docker-machine rm -f DO-01
docker-machine rm -f AWS-01
docker-machine rm -f AWS-02
docker-machine rm -f prometheusVM-AWS
echo "End of script."
