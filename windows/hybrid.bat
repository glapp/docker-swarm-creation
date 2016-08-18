REM Remove old nodes
docker-machine rm -y DO-MASTER AWS-01 DO-01 DO-02 kvstore glapp

REM Set credential variables
FOR /f "tokens=*" %%i IN (..\credentials) DO SET %%i

IF NOT DEFINED DO_TOKEN (EXIT /b)
IF NOT DEFINED AWS_ACCESS_KEY (EXIT /b)
IF NOT DEFINED AWS_SECRET_KEY (EXIT /b)

REM Create & provision KV store
docker-machine create -d digitalocean --digitalocean-access-token=%DO_TOKEN% --digitalocean-image "debian-8-x64" kvstore
FOR /f %%i IN ('docker-machine ip kvstore') DO SET KVSTORE=%%i
FOR /f "tokens=*" %%i IN ('docker-machine env kvstore') DO %%i
docker run -d --restart=always --net=host progrium/consul --server -bootstrap-expect 1
docker run -d -p 9090:3000 --restart=always clabs/metrics-server

REM Create swarm nodes
docker-machine create -d digitalocean --engine-label tier=1 --engine-label region=eu --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth0:2376" --digitalocean-access-token=%DO_TOKEN%  --digitalocean-region=ams2 --digitalocean-image "debian-8-x64" --swarm --swarm-master --swarm-discovery consul://%KVSTORE%:8500 DO-MASTER
docker-machine create -d digitalocean --engine-label tier=1 --engine-label region=us --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth0:2376" --digitalocean-access-token=%DO_TOKEN% --digitalocean-region=nyc1 --digitalocean-image "debian-8-x64" --swarm --swarm-discovery consul://%KVSTORE%:8500 DO-01
docker-machine create -d digitalocean --engine-label tier=2 --engine-label region=eu --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth0:2376" --digitalocean-access-token=%DO_TOKEN%  --digitalocean-region=ams2 --digitalocean-image "debian-8-x64" --digitalocean-size=1gb --swarm --swarm-discovery consul://%KVSTORE%:8500 DO-02
docker-machine create -d amazonec2 --engine-label tier=1 --engine-label region=us --engine-opt "cluster-store consul://%KVSTORE%:8500" --engine-opt "cluster-advertise eth0:2376" --amazonec2-access-key=%AWS_ACCESS_KEY% --amazonec2-secret-key=%AWS_SECRET_KEY% --amazonec2-region=us-east-1 --amazonec2-zone=a --swarm --swarm-discovery consul://%KVSTORE%:8500 AWS-01

REM Define variables
FOR /f %%i IN ('docker-machine ip DO-MASTER') DO SET DO_MASTER_IP=%%i
FOR /f %%i IN ('docker-machine ip AWS-01') DO SET AWS_01_IP=%%i
FOR /f %%i IN ('docker-machine ip DO-01') DO SET DO_01_IP=%%i
FOR /f %%i IN ('docker-machine ip DO-02') DO SET DO_02_IP=%%i

REM Provision DO-MASTER
FOR /f "tokens=*" %%i IN ('docker-machine env DO-MASTER') DO %%i
docker run -d --restart=always --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h DO-MASTER gliderlabs/registrator:latest -ip %DO_MASTER_IP% -internal consul://%KVSTORE%:8500
docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --publish=18080:8080 --detach=true google/cadvisor:latest

REM Provision AWS-01
FOR /f "tokens=*" %%i IN ('docker-machine env AWS-01') DO %%i
docker run -d --restart=always --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h AWS-01 gliderlabs/registrator:latest -ip %AWS_01_IP% -internal consul://%KVSTORE%:8500
docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --publish=18080:8080 --detach=true google/cadvisor:latest

REM Provision DO-01
FOR /f "tokens=*" %%i IN ('docker-machine env DO-01') DO %%i
docker run -d --restart=always --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h DO-01 gliderlabs/registrator:latest -ip %DO_01_IP% -internal consul://%KVSTORE%:8500
docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --publish=18080:8080 --detach=true google/cadvisor:latest

REM Provision DO-02
FOR /f "tokens=*" %%i IN ('docker-machine env DO-02') DO %%i
docker run -d --restart=always --name=registrator --volume=/var/run/docker.sock:/tmp/docker.sock -h DO-02 gliderlabs/registrator:latest -ip %DO_02_IP% -internal consul://%KVSTORE%:8500
docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --publish=18080:8080 --detach=true google/cadvisor:latest

FOR /f "tokens=*" %%i IN ('docker-machine env --swarm DO-MASTER') DO %%i
docker pull clabs/haproxylb:0.7

REM Set up prometheus
FOR /f "tokens=*" %%i IN ('docker-machine env kvstore') DO %%i
REM docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --publish=18080:8080 --detach=true google/cadvisor:latest
COPY prometheus_template.yml prometheus.yml
sed -i 's/MACHINE_1/%DO_MASTER_IP%/g' prometheus.yml
sed -i 's/MACHINE_2/%DO_01_IP%/g' prometheus.yml
sed -i 's/MACHINE_3/%DO_02_IP%/g' prometheus.yml
sed -i 's/MACHINE_4/%AWS_01_IP%/g' prometheus.yml
sed -i 's/COST_METRICS/54.246.169.99/g' prometheus.yml
sed -i 's/CLICK_METRICS/%KVSTORE%/g' prometheus.yml

docker-machine scp prometheus.yml kvstore:/tmp/prometheus.yml
docker run -d -p 19090:9090 -v /tmp/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus

REM Delete temp prometheus file
DEL prometheus.yml

REM Prepare glapp server for docker deployment of the project
docker-machine create -d digitalocean --digitalocean-access-token=%DO_TOKEN%  --digitalocean-region=ams2 --digitalocean-image "debian-8-x64" glapp
FOR /f "tokens=*" %%i IN ('docker-machine env glapp') DO %%i

REM Workaround for Windows to have the home directory in the right format
SET USR_TEMP=/%userprofile:\=/%
SET USR=%USR_TEMP::=%

REM Copy certs
docker-machine ssh glapp 'mkdir /swarmcerts'
docker-machine scp %USR%/.docker/machine/certs/ca.pem glapp:/swarmcerts/ca.pem
docker-machine scp %USR%/.docker/machine/certs/cert.pem glapp:/swarmcerts/cert.pem
docker-machine scp %USR%/.docker/machine/certs/key.pem glapp:/swarmcerts/key.pem
~
REM Set Swarm-Master ENV
SET SWARM_HOST=%DO_MASTER_IP%

PAUSE