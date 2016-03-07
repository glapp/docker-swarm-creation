#!/bin/bash
echo "Starting script"



# This script creates following VMs and containers:
#
# 1 kvstore on Digital Ocean in EU with:
#       1 Consul server (discovery service for the swarm)
#       1 cAdvisor (agent for prometheus)
#
# 1 swarm-master-do on Digital Ocean in EU with:
#       1 cAdvisor (agent for prometheus)
#
# 1 swarm-agent-do-01 on Digital Ocean in USA with:
#       1 cAdvisor (agent for prometheus)
#
# 1 swarm-agent-aws-01 on AWS in USA with:
#       1 cAdvisor (agent for prometheus)
#
# 1 swarm-agent-aws-02 on AWS in EU with:
#       1 cAdvisor (agent for prometheus)
#
# 1 prometheusVM-aws on AWS in USA with:
#       1 prometheus (Prometheus server)
#       1 cAdvisor (agent for prometheus)
#
# Total: 6 VMs and 8 containers


echo "Removing containers..."
docker-machine rm -f kvstore
docker-machine rm -f swarm-master-do
docker-machine rm -f swarm-agent-do-01
docker-machine rm -f swarm-agent-aws-01
docker-machine rm -f swarm-agent-aws-02
docker-machine rm -f prometheusVM-aws
echo "containers removed."

echo "Create kvstore..."
docker-machine create \
    -d digitalocean \
    --digitalocean-access-token=$DO_TOKEN \
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
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=18080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "kvstore created."

echo "Creating swarm-master-do..."
docker-machine create \
    -d digitalocean \
    --engine-label tier=1 \
    --engine-label region=eu \
    --engine-opt "cluster-store consul://$(docker-machine ip kvstore):8500" \
    --engine-opt "cluster-advertise eth0:2376" \
    --digitalocean-access-token=$DO_TOKEN \
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
    --publish=18080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "swarm-master-do created."

echo "Creating swarm-agent-do-01..."
docker-machine create \
    -d digitalocean \
    --engine-label tier=1 \
    --engine-label region=us \
    --engine-opt "cluster-store consul://$(docker-machine ip kvstore):8500" \
    --engine-opt "cluster-advertise eth0:2376" \
    --digitalocean-access-token=$DO_TOKEN \
    --digitalocean-region=nyc1 \
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
    --publish=18080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "swarm-agent-do-01 created."

echo "Creating swarm-agent-aws-01..."
docker-machine create \
    -d amazonec2 \
    --engine-label tier=1 \
    --engine-label region=us \
    --engine-opt "cluster-store consul://$(docker-machine ip kvstore):8500" \
    --engine-opt "cluster-advertise eth0:2376" \
    --amazonec2-access-key=$AWS_ACCESS_KEY \
    --amazonec2-secret-key=$AWS_SECRET_KEY \
    --amazonec2-region=us-east-1 \
    --amazonec2-zone=a \
    --swarm \
    --swarm-discovery consul://$(docker-machine ip kvstore):8500 \
    swarm-agent-aws-01
eval $(docker-machine env swarm-agent-aws-01)
docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=18080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "swarm-agent-aws-01 created."

echo "Creating swarm-agent-aws-02..."
docker-machine create \
    -d amazonec2 \
    --engine-label tier=1 \
    --engine-label region=eu \
    --engine-opt "cluster-store consul://$(docker-machine ip kvstore):8500" \
    --engine-opt "cluster-advertise eth0:2376" \
    --amazonec2-access-key=$AWS_ACCESS_KEY \
    --amazonec2-secret-key=$AWS_SECRET_KEY \
    --amazonec2-region=eu-central-1 \
    --amazonec2-zone=a \
    --swarm \
    --swarm-discovery consul://$(docker-machine ip kvstore):8500 \
    swarm-agent-aws-02
eval $(docker-machine env swarm-agent-aws-02)
docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=18080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "swarm-agent-aws-02 created."

echo "Create prometheusVM-aws..."
docker-machine create \
    -d amazonec2 \
    --amazonec2-access-key=$AWS_ACCESS_KEY \
    --amazonec2-secret-key=$AWS_SECRET_KEY \
    --amazonec2-region=us-east-1 \
    --amazonec2-zone=a \
    prometheusVM-aws
eval $(docker-machine env prometheusVM-aws)
docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=18080:8080 \
    --detach=true \
    google/cadvisor:latest
cp 'prometheus_template.yml' 'prometheus.yml'
sed -i s/MACHINE_1/$(docker-machine ip kvstore)/g 'prometheus.yml'
sed -i s/MACHINE_2/$(docker-machine ip swarm-master-do)/g 'prometheus.yml'
sed -i s/MACHINE_3/$(docker-machine ip swarm-agent-do-01)/g 'prometheus.yml'
sed -i s/MACHINE_4/$(docker-machine ip swarm-agent-aws-01)/g 'prometheus.yml'
sed -i s/MACHINE_5/$(docker-machine ip swarm-agent-aws-02)/g 'prometheus.yml'
sed -i s/MACHINE_6/$(docker-machine ip prometheusVM-aws)/g 'prometheus.yml'
docker-machine scp prometheus.yml prometheusVM-aws:/tmp/prometheus.yml
docker run \
    -d \
    -p 19090:9090 \
    -v /tmp/prometheus.yml:/etc/prometheus/prometheus.yml \
    prom/prometheus
echo "prometheusVM-aws created."

eval $(docker-machine env --swarm swarm-master-do)
docker info

echo "You may wanna point this client (terminal) to the swarm-master-do with the following command: eval \$(docker-machine env --swarm swarm-master-do)"

echo "Script is done!"