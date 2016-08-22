REM Remove old nodes
docker-machine rm -y swarm-agent-00 swarm-agent-01 swarm-master kvstore

REM Create & provision KV store
docker-machine create -d virtualbox --virtualbox-no-vtx-check kvstore
FOR /f %%i IN ('docker-machine ip kvstore') DO SET KVSTORE=%%i
FOR /f "tokens=*" %%i IN ('docker-machine env kvstore') DO %%i
docker run -d --restart=always --net=host progrium/consul --server -bootstrap-expect 1
docker run -d -p 9090:3000 --restart=always glapp/metrics-server
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
FOR /f "tokens=*" %%i IN ('docker-machine env swarm-master') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-master gliderlabs/registrator:latest -ip %SWARM_MASTER_IP% -internal consul://%KVSTORE%:8500
docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --publish=18080:8080 --detach=true google/cadvisor:latest
REM docker-machine ssh swarm-master "echo 'ifconfig eth1 %SWARM_MASTER% netmask 255.255.255.0 broadcast 192.168.99.255 up' | sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null"

REM Provision swarm-agent-00
FOR /f "tokens=*" %%i IN ('docker-machine env swarm-agent-00') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent-00 gliderlabs/registrator:latest -ip %SWARM_AGENT_00_IP% -internal consul://%KVSTORE%:8500
docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --publish=18080:8080 --detach=true google/cadvisor:latest
REM docker-machine ssh swarm-agent-00 "echo 'ifconfig eth1 %SWARM_AGENT_00% netmask 255.255.255.0 broadcast 192.168.99.255 up' | sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null"

REM Provision swarm-agent-01
FOR /f "tokens=*" %%i IN ('docker-machine env swarm-agent-01') DO %%i
docker run -d --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h swarm-agent-01 gliderlabs/registrator:latest -ip %SWARM_AGENT_01_IP% -internal consul://%KVSTORE%:8500
docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --publish=18080:8080 --detach=true google/cadvisor:latest
REM docker-machine ssh swarm-agent-01 "echo 'ifconfig eth1 %SWARM_AGENT_01% netmask 255.255.255.0 broadcast 192.168.99.255 up' | sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null"

FOR /f "tokens=*" %%i IN ('docker-machine env --swarm swarm-master') DO %%i
docker pull clabs/haproxylb:0.7

REM Set up prometheus
FOR /f "tokens=*" %%i IN ('docker-machine env kvstore') DO %%i
docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --publish=18080:8080 --detach=true google/cadvisor:latest
COPY prometheus_template.yml prometheus.yml
sed -i 's/MACHINE_1/%KVSTORE%/g' prometheus.yml
sed -i 's/MACHINE_2/%SWARM_MASTER_IP%/g' prometheus.yml
sed -i 's/MACHINE_3/%SWARM_AGENT_00_IP%/g' prometheus.yml
sed -i 's/MACHINE_4/%SWARM_AGENT_01_IP%/g' prometheus.yml
docker-machine scp prometheus.yml kvstore:/tmp/prometheus.yml
docker run -d -p 19090:9090 -v /tmp/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus

REM Delete temp prometheus file
DEL prometheus.yml

REM Prepare local for docker deployment of the project
docker-machine create -d virtualbox --virtualbox-no-vtx-check local
FOR /f "tokens=*" %%i IN ('docker-machine env local') DO %%i

REM Set Swarm-Master ENV
SET SWARM_HOST=%SWARM_MASTER_IP%

PAUSE