#!/bin/bash
echo "Starting script..."

docker-machine rm -f kvstore
docker-machine rm -f swarm-master
docker-machine rm -f swarm-agent-01
docker-machine rm -f swarm-agent-02

docker-machine create -d virtualbox kvstore
eval $(docker-machine env kvstore)
docker run -d --net=host progrium/consul --server -bootstrap-expect 1

docker-machine create -d virtualbox --engine-opt "cluster-store consul://$(docker-machine ip kvstore):8500" --engine-opt "cluster-advertise eth1:2376" --swarm --swarm-master --swarm-discovery consul://$(docker-machine ip kvstore):8500 swarm-master
docker-machine create -d virtualbox --engine-opt "cluster-store consul://$(docker-machine ip kvstore):8500" --engine-opt "cluster-advertise eth1:2376" --swarm --swarm-discovery consul://$(docker-machine ip kvstore):8500 swarm-agent-01
docker-machine create -d virtualbox --engine-opt "cluster-store consul://$(docker-machine ip kvstore):8500" --engine-opt "cluster-advertise eth1:2376" --swarm --swarm-discovery consul://$(docker-machine ip kvstore):8500 swarm-agent-02

docker-machine env --swarm swarm-master

echo "End of script."
