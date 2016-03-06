#!/bin/bash
echo "Starting script..."
docker-machine rm -f kvstore
docker-machine rm -f swarm-master-do
docker-machine rm -f swarm-agent-do-01
docker-machine rm -f swarm-agent-aws-01
docker-machine rm -f swarm-agent-aws-02
docker-machine rm -f prometheusVM-aws
echo "End of script."
