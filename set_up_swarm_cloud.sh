#!/bin/bash
echo "Starting script"

echo "Removing containers..."
docker-machine rm -f kvstore
docker-machine rm -f swarm-master-do
docker-machine rm -f swarm-agent-do-01
docker-machine rm -f swarm-agent-aws-01
echo "containers removed."

echo "Create kvstore..."
docker-machine create \
    -d digitalocean \
    --digitalocean-access-token=<here access toker from Digital Ocean Website> \
    --digitalocean-region=ams2 \
    --digitalocean-image "debian-8-x64" \
    kvstore
eval $(docker-machine env kvstore)
docker run \
    -d \
    -p 8400:8400 \
    -p 8500:8500 \
    -p 8600:53/udp \
    --net=host \
    progrium/consul \
    --server \
    -bootstrap-expect 1 \
    -ui-dir /ui
docker run \
    --hostname=$(docker-machine ip kvstore) \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=8080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "kvstore created."

echo "Creating swarm-master-do..."
docker-machine create \
    -d digitalocean \
    --engine-opt "cluster-store consul://$(docker-machine ip kvstore):8500" \
    --engine-opt "cluster-advertise eth0:2376" \
    --digitalocean-access-token=<here access toker from Digital Ocean Website> \
    --digitalocean-region=ams2 \
    --digitalocean-image "debian-8-x64" \
    --swarm \
    --swarm-master \
    --swarm-discovery consul://$(docker-machine ip kvstore):8500 \
    swarm-master-do
eval $(docker-machine env swarm-master-do)
docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=8080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "swarm-master-do created."

echo "Creating swarm-agent-do-01..."
docker-machine create \
    -d digitalocean \
    --engine-opt "cluster-store consul://$(docker-machine ip kvstore):8500" \
    --engine-opt "cluster-advertise eth0:2376" \
    --digitalocean-access-token=<here access toker from Digital Ocean Website> \
    --digitalocean-region=ams2 \
    --digitalocean-image "debian-8-x64" \
    --swarm \
    --swarm-discovery consul://$(docker-machine ip kvstore):8500 \
    swarm-agent-do-01
eval $(docker-machine env swarm-agent-do-01)
docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=8080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "swarm-agent-do-01 created."

echo "Creating swarm-agent-aws-01..."
docker-machine create \
    -d amazonec2 \
    --engine-opt "cluster-store consul://$(docker-machine ip kvstore):8500" \
    --engine-opt "cluster-advertise eth0:2376" \
    --amazonec2-access-key=<here access key from AWS Webseite> \
    --amazonec2-secret-key=<here secret key from AWS Webseite> \
    --amazonec2-region=us-east-1 \
    --amazonec2-zone=a \
    --swarm \
    --swarm-discovery consul://$(docker-machine ip kvstore):8500 \
    swarm-agent-aws-01
val $(docker-machine env swarm-agent-aws-01)
docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=8080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "swarm-agent-aws-01 created."

eval $(docker-machine env --swarm swarm-master-do)
docker info

echo "You may wanna point this client (terminal) to the swarm-master-do with the following command: eval \$(docker-machine env --swarm swarm-master-do)"

echo "Script is done!"