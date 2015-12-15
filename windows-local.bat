docker-machine rm swarm-agent-00 swarm-agent-01 swarm-master kvstore
docker-machine create -d virtualbox kvstore
FOR /f %%i IN ('docker-machine ip kvstore') DO SET KVSTORE=%%i
FOR /f "tokens=*" %%i IN ('docker-machine env --shell=cmd kvstore') DO %%i
docker run -d --net=host --restart always progrium/consul --server -bootstrap-expect 1
docker-machine create -d virtualbox --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth1:2376" --swarm --swarm-master --swarm-discovery consul://%KVSTORE%:8500 swarm-master
FOR /f %%i IN ('docker-machine ip swarm-master') DO SET SWARM_MASTER_IP=%%i
FOR /f "tokens=*" %%i IN ('docker-machine env --shell=cmd swarm-master') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-master gliderlabs/registrator:latest -ip %SWARM_MASTER_IP% consul://%KVSTORE%:8500
docker-machine create -d virtualbox --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth1:2376" --swarm --swarm-discovery consul://%KVSTORE%:8500 swarm-agent-00
FOR /f %%i IN ('docker-machine ip swarm-agent-00') DO SET SWARM_AGENT_00_IP=%%i
FOR /f "tokens=*" %%i IN ('docker-machine env --shell=cmd swarm-agent-00') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent-00 gliderlabs/registrator:latest -ip %SWARM_AGENT_00_IP% consul://%KVSTORE%:8500
docker-machine create -d virtualbox --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth1:2376" --swarm --swarm-discovery consul://%KVSTORE%:8500 swarm-agent-01
FOR /f %%i IN ('docker-machine ip swarm-agent-01') DO SET SWARM_AGENT_01_IP=%%i
FOR /f "tokens=*" %%i IN ('docker-machine env --shell=cmd swarm-agent-01') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent-00 gliderlabs/registrator:latest -ip %SWARM_AGENT_01_IP% consul://%KVSTORE%:8500
PAUSE