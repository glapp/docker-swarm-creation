REM Remove old nodes
docker-machine rm -y swarm-agent-00 swarm-agent-01 swarm-master kvstore

REM Create & provision KV store
docker-machine create -d virtualbox --virtualbox-no-vtx-check kvstore
FOR /f %%i IN ('docker-machine ip kvstore') DO SET KVSTORE=%%i
FOR /f "tokens=*" %%i IN ('docker-machine env --shell=cmd kvstore') DO %%i
docker run -d --restart=always --net=host progrium/consul --server -bootstrap-expect 1
REM docker-machine ssh kvstore "echo 'ifconfig eth1 %KVSTORE% netmask 255.255.255.0 broadcast 192.168.99.255 up' | sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null"

REM Create swarm nodes
docker-machine create -d virtualbox --virtualbox-no-vtx-check --engine-label tier=1 --engine-label region=eu --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth1:2376" --swarm --swarm-master --swarm-discovery consul://%KVSTORE%:8500 swarm-master
docker-machine create -d virtualbox --virtualbox-no-vtx-check --engine-label tier=2 --engine-label region=us --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth1:2376" --swarm --swarm-discovery consul://%KVSTORE%:8500 swarm-agent-00
docker-machine create -d virtualbox --virtualbox-no-vtx-check --engine-label tier=1 --engine-label region=us --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth1:2376" --swarm --swarm-discovery consul://%KVSTORE%:8500 swarm-agent-01

REM Define variables
FOR /f %%i IN ('docker-machine ip swarm-master') DO SET SWARM_MASTER_IP=%%i
FOR /f %%i IN ('docker-machine ip swarm-agent-00') DO SET SWARM_AGENT_00_IP=%%i
FOR /f %%i IN ('docker-machine ip swarm-agent-01') DO SET SWARM_AGENT_01_IP=%%i

REM Provision swarm-master
FOR /f "tokens=*" %%i IN ('docker-machine env --shell=cmd swarm-master') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-master gliderlabs/registrator:latest -ip %SWARM_MASTER_IP% -internal consul://%KVSTORE%:8500
REM docker-machine ssh swarm-master "echo 'ifconfig eth1 %SWARM_MASTER% netmask 255.255.255.0 broadcast 192.168.99.255 up' | sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null"

REM Provision swarm-agent-00
FOR /f "tokens=*" %%i IN ('docker-machine env --shell=cmd swarm-agent-00') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent-00 gliderlabs/registrator:latest -ip %SWARM_AGENT_00_IP% -internal consul://%KVSTORE%:8500
REM docker-machine ssh swarm-agent-00 "echo 'ifconfig eth1 %SWARM_AGENT_00% netmask 255.255.255.0 broadcast 192.168.99.255 up' | sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null"

REM Provision swarm-agent-01
FOR /f "tokens=*" %%i IN ('docker-machine env --shell=cmd swarm-agent-01') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent-00 gliderlabs/registrator:latest -ip %SWARM_AGENT_01_IP% -internal consul://%KVSTORE%:8500
REM docker-machine ssh swarm-agent-01 "echo 'ifconfig eth1 %SWARM_AGENT_01% netmask 255.255.255.0 broadcast 192.168.99.255 up' | sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null"

PAUSE