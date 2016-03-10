#!/bin/bash
echo "Starting script"

# This script creates following VMs and containers:
#
# 1 kvstore-DO on Digital Ocean with:
#       1 Consul server (discovery service for the swarm)
#       1 cAdvisor (agent for prometheus)
#
# 1 DO-master on Digital Ocean (region eu, tier 1) with:
#       1 cAdvisor (agent for prometheus)
#
# 1 DO-01 on Digital Ocean (region us, tier 1) with:
#       1 cAdvisor (agent for prometheus)
#
# 1 DO-02 on Digital Ocean (region eu, tier 2) with:
#       1 cAdvisor (agent for prometheus)
#
# 1 AWS-01 on AWS (region us, tier 1) with:
#       1 cAdvisor (agent for prometheus)
#
# 1 prometheusVM-AWS on AWS with:
#       1 prometheus (Prometheus server)
#       1 cAdvisor (agent for prometheus)
#
# Total: 6 VMs and 8 containers


echo "Removing containers..."
docker-machine rm -y kvstore-DO DO-master DO-01 DO-02 AWS-01 prometheusVM-AWS
echo "containers removed."


echo "Create kvstore-DO..."
docker-machine create \
    -d digitalocean \
    --digitalocean-access-token=$DO_TOKEN \
    --digitalocean-region=ams2 \
    --digitalocean-image "debian-8-x64" \
    kvstore-DO
eval $(docker-machine env kvstore-DO)
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
echo "kvstore-DO created."


echo "Creating DO-master..."
docker-machine create \
    -d digitalocean \
    --engine-label tier=1 \
    --engine-label region=eu \
    --engine-opt "cluster-store consul://$(docker-machine ip kvstore-DO):8500" \
    --engine-opt "cluster-advertise eth0:2376" \
    --digitalocean-access-token=$DO_TOKEN \
    --digitalocean-region=ams2 \
    --digitalocean-image "debian-8-x64" \
    --swarm \
    --swarm-master \
    --swarm-discovery consul://$(docker-machine ip kvstore-DO):8500 \
    DO-master
eval $(docker-machine env DO-master)
docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=18080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "DO-master created."


echo "Creating DO-01..."
docker-machine create \
    -d digitalocean \
    --engine-label tier=1 \
    --engine-label region=us \
    --engine-opt "cluster-store consul://$(docker-machine ip kvstore-DO):8500" \
    --engine-opt "cluster-advertise eth0:2376" \
    --digitalocean-access-token=$DO_TOKEN \
    --digitalocean-region=nyc1 \
    --digitalocean-image "debian-8-x64" \
    --swarm \
    --swarm-discovery consul://$(docker-machine ip kvstore-DO):8500 \
    DO-01
eval $(docker-machine env DO-01)
docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=18080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "DO-01 created."


echo "Creating DO-02..."
docker-machine create \
    -d digitalocean \
    --engine-label tier=2 \
    --engine-label region=eu \
    --engine-opt "cluster-store consul://$(docker-machine ip kvstore-DO):8500" \
    --engine-opt "cluster-advertise eth0:2376" \
    --digitalocean-access-token=$DO_TOKEN \
    --digitalocean-region=ams2 \
    --digitalocean-image "debian-8-x64" \
    --digitalocean-size=1gb \
    --swarm \
    --swarm-discovery consul://$(docker-machine ip kvstore-DO):8500 \
    DO-02
eval $(docker-machine env DO-02)
docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=18080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "DO-02 created."


echo "Creating AWS-01..."
docker-machine create \
    -d amazonec2 \
    --engine-label tier=1 \
    --engine-label region=us \
    --engine-opt "cluster-store consul://$(docker-machine ip kvstore-DO):8500" \
    --engine-opt "cluster-advertise eth0:2376" \
    --amazonec2-access-key=$AWS_ACCESS_KEY \
    --amazonec2-secret-key=$AWS_SECRET_KEY \
    --amazonec2-region=us-east-1 \
    --amazonec2-zone=a \
    --swarm \
    --swarm-discovery consul://$(docker-machine ip kvstore-DO):8500 \
    AWS-01
eval $(docker-machine env AWS-01)
docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=18080:8080 \
    --detach=true \
    google/cadvisor:latest
echo "AWS-01 created."


echo "Create prometheusVM-AWS..."
docker-machine create \
    -d amazonec2 \
    --engine-label region=US-East \
    --amazonec2-access-key=$AWS_ACCESS_KEY \
    --amazonec2-secret-key=$AWS_SECRET_KEY \
    --amazonec2-region=us-east-1 \
    --amazonec2-zone=a \
    prometheusVM-AWS
eval $(docker-machine env prometheusVM-AWS)
docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=18080:8080 \
    --detach=true \
    google/cadvisor:latest
cp 'prometheus_template.yml' 'prometheus.yml'
sed -i s/MACHINE_1/$(docker-machine ip kvstore-DO)/g 'prometheus.yml'
sed -i s/MACHINE_2/$(docker-machine ip DO-master)/g 'prometheus.yml'
sed -i s/MACHINE_3/$(docker-machine ip DO-01)/g 'prometheus.yml'
sed -i s/MACHINE_4/$(docker-machine ip DO-02)/g 'prometheus.yml'
sed -i s/MACHINE_5/$(docker-machine ip AWS-01)/g 'prometheus.yml'
sed -i s/MACHINE_6/$(docker-machine ip prometheusVM-AWS)/g 'prometheus.yml'
docker-machine scp prometheus.yml prometheusVM-aws:/tmp/prometheus.yml
docker run \
    -d \
    -p 19090:9090 \
    -v /tmp/prometheus.yml:/etc/prometheus/prometheus.yml \
    prom/prometheus
echo "prometheusVM-AWS created."

eval $(docker-machine env --swarm DO-master)
docker info

echo "You may wanna point this client (terminal) to the DO-master with the following command: eval \$(docker-machine env --swarm DO-master)"

echo "Script is done!"

