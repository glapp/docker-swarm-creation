REM Remove old nodes
docker-machine rm -y MASTER-DO AWS DO

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
REM docker-machine ssh kvstore "echo 'ifconfig eth1 %KVSTORE% netmask 255.255.255.0 broadcast 192.168.99.255 up' | sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null"

REM Create swarm nodes
docker-machine create -d digitalocean --engine-label tier=1 --engine-label region=eu --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth0:2376" --digitalocean-access-token=%DO_TOKEN%  --digitalocean-region=ams2 --digitalocean-image "debian-8-x64" --swarm --swarm-master --swarm-discovery consul://%KVSTORE%:8500 MASTER-DO
docker-machine create -d amazonec2 --engine-label tier=1 --engine-label region=us --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth0:2376" --amazonec2-access-key=%AWS_ACCESS_KEY% --amazonec2-secret-key=%AWS_SECRET_KEY% --amazonec2-region=us-east-1 --amazonec2-zone=a --swarm --swarm-discovery consul://%KVSTORE%:8500 AWS
docker-machine create -d digitalocean --engine-label tier=2 --engine-label region=us --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth0:2376" --digitalocean-access-token=%DO_TOKEN% --digitalocean-region=nyc1 --digitalocean-image "debian-8-x64" --swarm --swarm-discovery consul://%KVSTORE%:8500 DO

REM Define variables
FOR /f %%i IN ('docker-machine ip MASTER-DO') DO SET MASTER_IP=%%i
FOR /f %%i IN ('docker-machine ip AWS') DO SET AWS_IP=%%i
FOR /f %%i IN ('docker-machine ip DO') DO SET DO_IP=%%i

REM Provision swarm-master
FOR /f "tokens=*" %%i IN ('docker-machine env MASTER-DO') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-master gliderlabs/registrator:latest -ip %MASTER_IP% consul://%KVSTORE%:8500
REM docker-machine ssh swarm-master "echo 'ifconfig eth1 %SWARM_MASTER% netmask 255.255.255.0 broadcast 192.168.99.255 up' | sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null"

REM Provision swarm-agent-00
FOR /f "tokens=*" %%i IN ('docker-machine env AWS') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent-00 gliderlabs/registrator:latest -ip %AWS_IP% consul://%KVSTORE%:8500
REM docker-machine ssh swarm-agent-00 "echo 'ifconfig eth1 %SWARM_AGENT_00% netmask 255.255.255.0 broadcast 192.168.99.255 up' | sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null"

REM Provision swarm-agent-DO
FOR /f "tokens=*" %%i IN ('docker-machine env DO') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent-00 gliderlabs/registrator:latest -ip %DO_IP% consul://%KVSTORE%:8500
REM docker-machine ssh swarm-agent-DO "echo 'ifconfig eth1 %SWARM_AGENT_DO% netmask 255.255.255.0 broadcast 192.168.99.255 up' | sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null"

PAUSE