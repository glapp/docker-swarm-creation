#!/bin/bash

echo "Starting script"

start=$(date +"%T")
echo "Current time : $start"

echo "set enviornment variables..."
source ~/sw-projects/docker-swarm-creation/credentials

echo "Creating glapp..."
docker-machine create \
    -d digitalocean \
    --digitalocean-access-token=$DO_TOKEN \
    --digitalocean-region=ams2 \
    --digitalocean-size=2gb \
    --digitalocean-image "debian-8-x64" \
    glapp
eval $(docker-machine env glapp)

export SWARM_HOST=$(docker-machine ip DO-master)

docker-machine ssh glapp 'mkdir /swarmcerts'
docker-machine scp ~/.docker/machine/certs/ca.pem glapp:/swarmcerts/ca.pem
docker-machine scp ~/.docker/machine/certs/cert.pem glapp:/swarmcerts/cert.pem
docker-machine scp ~/.docker/machine/certs/key.pem glapp:/swarmcerts/key.pem

cd ~/sw-projects/WebstormProjects/gla-sails
docker-compose up -d

echo "glapp created."

echo "You may wanna point this client (terminal) to the DO-master with the following command: eval \$(docker-machine env --swarm DO-master)"
echo "You may wanna point this client (terminal) to the glapp with the following command: eval \$(docker-machine env glapp)"

echo "Start time : $start"
end=$(date +"%T")
echo "End time : $end"
echo "Script is done!"
