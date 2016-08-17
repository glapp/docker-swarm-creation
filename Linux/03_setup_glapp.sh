#!/bin/bash

echo "Starting script"

start=$(date +"%T")
echo "Current time : $start"

echo "Creating glapp..."
docker-machine create \
    -d virtualbox \
    glapp
eval $(docker-machine env glapp)
export SWARM_HOST=$(docker-machine ip DO-master):3376
cp -avr ~/.docker/machine/certs ~/sw-projects/WebstormProjects/gla-sails/config
cd ~/sw-projects/WebstormProjects/gla-sails
docker-compose up -d
echo "glapp created."

echo "You may wanna point this client (terminal) to the DO-master with the following command: eval \$(docker-machine env --swarm DO-master)"
echo "You may wanna point this client (terminal) to the glapp with the following command: eval \$(docker-machine env glapp)"

echo "Start time : $start"
end=$(date +"%T")
echo "End time : $end"
echo "Script is done!"
