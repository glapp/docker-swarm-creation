REM Remove old nodes
docker-machine rm -y kvstore swarm-master swarm-agent

REM Create & provision KV store
docker-machine create -d virtualbox --virtualbox-no-vtx-check kvstore
FOR /f %%i IN ('docker-machine ip kvstore') DO SET KVSTORE=%%i
FOR /f "tokens=*" %%i IN ('docker-machine env kvstore') DO %%i
docker run -d --restart=always --net=host progrium/consul --server -bootstrap-expect 1
docker run -d -p 9090:3000 --restart=always clabs/metrics-server

REM Create swarm nodes
docker-machine create -d virtualbox --virtualbox-no-vtx-check --engine-label tier=1 --engine-label region=eu --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth1:2376" --swarm --swarm-master --swarm-discovery consul://%KVSTORE%:8500 swarm-master
docker-machine create -d virtualbox --virtualbox-no-vtx-check --engine-label tier=2 --engine-label region=us --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth1:2376" --swarm --swarm-discovery consul://%KVSTORE%:8500 swarm-agent

REM Define variables
FOR /f %%i IN ('docker-machine ip swarm-master') DO SET SWARM_MASTER_IP=%%i
FOR /f %%i IN ('docker-machine ip swarm-agent') DO SET  SWARM_AGENT_IP=%%i

REM Provision swarm-master
FOR /f "tokens=*" %%i IN ('docker-machine env swarm-master') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-master gliderlabs/registrator:latest -ip %SWARM_MASTER_IP% -internal consul://%KVSTORE%:8500

REM Provision swarm-agent
FOR /f "tokens=*" %%i IN ('docker-machine env swarm-agent') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent gliderlabs/registrator:latest -ip %SWARM_AGENT_IP% -internal consul://%KVSTORE%:8500

REM Prepare Proxy
FOR /f "tokens=*" %%i IN ('docker-machine env --swarm swarm-master') DO %%i
docker pull clabs/haproxylb:0.7

REM Prepare local for docker deployment of the project
docker-machine create -d virtualbox --virtualbox-no-vtx-check local
FOR /f "tokens=*" %%i IN ('docker-machine env local') DO %%i

REM Set Swarm-Master ENV
SET SWARM_HOST=%SWARM_MASTER_IP%

PAUSE