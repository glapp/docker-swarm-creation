#!/bin/bash
echo "Starting script"


echo "Removing containers..."
docker-machine rm do-kvstore
docker-machine rm do-swarm-master
docker-machine rm do-swarm-agent-00
docker-machine rm do-swarm-agent-01
echo "containers removed."

echo "Create do-kvstore..."
docker-machine create -d digitalocean --digitalocean-access-token=<here access token> --digitalocean-region=ams2 --digitalocean-image "debian-8-x64" do-kvstore
eval $(docker-machine env do-kvstore)
echo "do-kvstore created."

echo "Creating Consul container on do-kvstore"
docker run -d --net=host progrium/consul --server -bootstrap-expect 1 -ui-dir /ui
echo "Consul container created."

echo "Creating Swarm-Master..."
docker-machine create -d digitalocean --engine-opt "cluster-store consul://$(docker-machine ip do-kvstore):8500" --engine-opt "cluster-advertise eth0:2376" --digitalocean-access-token=<here access token> --digitalocean-region=ams2 --digitalocean-image "debian-8-x64" --swarm --swarm-master --swarm-discovery consul://$(docker-machine ip do-kvstore):8500 do-swarm-master
echo "Swarm-Master created."

echo "Creating Swarm-Node 00..."
docker-machine create -d digitalocean --engine-opt "cluster-store consul://$(docker-machine ip do-kvstore):8500" --engine-opt "cluster-advertise eth0:2376" --digitalocean-access-token=<here access token> --digitalocean-region=ams2 --digitalocean-image "debian-8-x64" --swarm --swarm-discovery consul://$(docker-machine ip do-kvstore):8500 do-swarm-agent-00
echo "Swarm-Node 00 created."

echo "Creating Swarm-Node 01..."
docker-machine create -d digitalocean --engine-opt "cluster-store consul://$(docker-machine ip do-kvstore):8500" --engine-opt "cluster-advertise eth0:2376" --digitalocean-access-token=<here access token> --digitalocean-region=ams2 --digitalocean-image "debian-8-x64" --swarm --swarm-discovery consul://$(docker-machine ip do-kvstore):8500 do-swarm-agent-01
echo "Swarm-Node 01 created."

eval $(docker-machine env --swarm do-swarm-master)
docker info

echo "Script is done!"