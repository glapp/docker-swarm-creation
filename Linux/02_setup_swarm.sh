#!/bin/bash

echo "Starting script"
echo "Removing containers..."
docker-machine rm -f kvstore-DO DO-master DO-01 DO-02 AWS-01 glapp
echo "containers removed."

start=$(date +"%T")
echo "Current time : $start"

echo "set enviornment variables..."
source ~/sw-projects/docker-swarm-creation/credentials

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
docker run \
	-d \
	-p 9090:3000 \
	--restart=always \
	clabs/metrics-server
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
docker run \
    -d \
    --name=registrator \
    --volume=/var/run/docker.sock:/tmp/docker.sock \
    -h DO-master \
    gliderlabs/registrator:latest \
    -ip $(docker-machine ip DO-master) \
    -internal consul://$(docker-machine ip kvstore-DO):8500
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
docker run \
    -d \
    --name=registrator \
    --volume=/var/run/docker.sock:/tmp/docker.sock \
    -h DO-01 \
    gliderlabs/registrator:latest \
    -ip $(docker-machine ip DO-01) \
    -internal consul://$(docker-machine ip kvstore-DO):8500
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
    --digitalocean-size=2gb \
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
docker run \
    -d \
    --name=registrator \
    --volume=/var/run/docker.sock:/tmp/docker.sock \
    -h DO-02 \
    gliderlabs/registrator:latest \
    -ip $(docker-machine ip DO-02) \
    -internal consul://$(docker-machine ip kvstore-DO):8500
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
docker run \
    -d \
    --name=registrator \
    --volume=/var/run/docker.sock:/tmp/docker.sock \
    -h AWS-01 \
    gliderlabs/registrator:latest \
    -ip $(docker-machine ip AWS-01) \
    -internal consul://$(docker-machine ip kvstore-DO):8500
echo "AWS-01 created."


echo "Creating Prometheus server on kvstore..."
eval $(docker-machine env kvstore-DO)
cp '/home/riccardo/prometheus/prometheus-cloud/prometheus_template.yml' '/home/riccardo/prometheus/prometheus-cloud/prometheus.yml'
sed -i s/MACHINE_1/$(docker-machine ip kvstore-DO)/g '/home/riccardo/prometheus/prometheus-cloud/prometheus.yml'
sed -i s/MACHINE_2/$(docker-machine ip DO-master)/g '/home/riccardo/prometheus/prometheus-cloud/prometheus.yml'
sed -i s/MACHINE_3/$(docker-machine ip DO-01)/g '/home/riccardo/prometheus/prometheus-cloud/prometheus.yml'
sed -i s/MACHINE_4/$(docker-machine ip AWS-01)/g '/home/riccardo/prometheus/prometheus-cloud/prometheus.yml'
sed -i s/MACHINE_5/$(docker-machine ip DO-02)/g '/home/riccardo/prometheus/prometheus-cloud/prometheus.yml'
docker-machine scp /home/riccardo/prometheus/prometheus-cloud/prometheus.yml kvstore-DO:/tmp/prometheus.yml
docker run \
    -d \
    -p 19090:9090 \
    -v /tmp/prometheus.yml:/etc/prometheus/prometheus.yml \
    prom/prometheus
echo "Prometheus server created."

# for comments use:
: <<'END_COMMENT'
# script content to be commented
END_COMMENT


echo "You may wanna point this client (terminal) to the DO-master with the following command: eval \$(docker-machine env --swarm DO-master)"

echo "Start time : $start"
end=$(date +"%T")
echo "End time : $end"
echo "Script is done!"
