REM Remove old node
docker-machine rm -y glapp

REM Set credential variables
FOR /f "tokens=*" %%i IN (..\credentials) DO SET %%i

IF NOT DEFINED DO_TOKEN (EXIT /b)
IF NOT DEFINED AWS_ACCESS_KEY (EXIT /b)
IF NOT DEFINED AWS_SECRET_KEY (EXIT /b)

REM Set Swarm-Master ENV
SET SWARM_HOST=%DO_MASTER_IP%

REM Prepare glapp server for docker deployment of the project
docker-machine create -d digitalocean --digitalocean-access-token=%DO_TOKEN%  --digitalocean-region=ams2 --digitalocean-size=2gb --digitalocean-image "debian-8-x64" glapp
FOR /f "tokens=*" %%i IN ('docker-machine env glapp') DO %%i

REM Workaround for Windows to have the home directory in the right format
SET USR_TEMP=/%userprofile:\=/%
SET USR=%USR_TEMP::=%

REM Copy certs
docker-machine ssh glapp 'mkdir /swarmcerts'
docker-machine scp %USR%/.docker/machine/certs/ca.pem glapp:/swarmcerts/ca.pem
docker-machine scp %USR%/.docker/machine/certs/cert.pem glapp:/swarmcerts/cert.pem
docker-machine scp %USR%/.docker/machine/certs/key.pem glapp:/swarmcerts/key.pem

PAUSE