REM Remove old nodes
docker-machine rm -y DO-MASTER AWS DO-01 DO-02

REM Set credential variables
FOR /f "tokens=*" %%i IN (..\credentials) DO SET %%i

IF NOT DEFINED DO_TOKEN (EXIT /b)
IF NOT DEFINED AWS_ACCESS_KEY (EXIT /b)
IF NOT DEFINED AWS_SECRET_KEY (EXIT /b)

REM Create & provision KV store
docker-machine create -d digitalocean --digitalocean-access-token=%DO_TOKEN% kvstore
FOR /f %%i IN ('docker-machine ip kvstore') DO SET KVSTORE=%%i
FOR /f "tokens=*" %%i IN ('docker-machine env kvstore') DO %%i
docker run -d --restart=always --net=host progrium/consul --server -bootstrap-expect 1

REM Create swarm nodes
docker-machine create -d digitalocean --engine-label tier=1 --engine-label region=eu --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth0:2376" --digitalocean-access-token=%DO_TOKEN%  --digitalocean-region=ams2 --digitalocean-image "debian-8-x64" --swarm --swarm-master --swarm-discovery consul://%KVSTORE%:8500 DO-MASTER
docker-machine create -d digitalocean --engine-label tier=1 --engine-label region=us --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth0:2376" --digitalocean-access-token=%DO_TOKEN% --digitalocean-region=nyc1 --digitalocean-image "debian-8-x64" --swarm --swarm-discovery consul://%KVSTORE%:8500 DO-01
docker-machine create -d digitalocean --engine-label tier=2 --engine-label region=eu --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth0:2376" --digitalocean-access-token=%DO_TOKEN%  --digitalocean-region=ams2 --digitalocean-image "debian-8-x64" --digitalocean-size=1gb --swarm --swarm-master --swarm-discovery consul://%KVSTORE%:8500 DO-02
docker-machine create -d amazonec2 --engine-label tier=1 --engine-label region=us --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth0:2376" --amazonec2-access-key=%AWS_ACCESS_KEY% --amazonec2-secret-key=%AWS_SECRET_KEY% --amazonec2-region=us-east-1 --amazonec2-zone=a --swarm --swarm-discovery consul://%KVSTORE%:8500 AWS

REM Define variables
FOR /f %%i IN ('docker-machine ip DO-MASTER') DO SET DO_MASTER_IP=%%i
FOR /f %%i IN ('docker-machine ip AWS') DO SET AWS_IP=%%i
FOR /f %%i IN ('docker-machine ip DO-01') DO SET DO_01_IP=%%i
FOR /f %%i IN ('docker-machine ip DO-02') DO SET DO_02_IP=%%i

REM Provision DO-MASTER
FOR /f "tokens=*" %%i IN ('docker-machine env DO-MASTER') DO %%i
docker run -d --restart=always --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-master gliderlabs/registrator:latest -ip %DO_MASTER_IP% consul://%KVSTORE%:8500

REM Provision AWS
FOR /f "tokens=*" %%i IN ('docker-machine env AWS') DO %%i
docker run -d --restart=always --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent-00 gliderlabs/registrator:latest -ip %AWS_IP% consul://%KVSTORE%:8500

REM Provision DO-01
FOR /f "tokens=*" %%i IN ('docker-machine env DO-01') DO %%i
docker run -d --restart=always --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent-00 gliderlabs/registrator:latest -ip %DO_01_IP% consul://%KVSTORE%:8500

REM Provision DO-02
FOR /f "tokens=*" %%i IN ('docker-machine env DO-02') DO %%i
docker run -d --restart=always --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent-00 gliderlabs/registrator:latest -ip %DO_02_IP% consul://%KVSTORE%:8500

PAUSE