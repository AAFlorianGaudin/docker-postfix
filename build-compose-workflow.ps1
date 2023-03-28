docker stop postfix-relay
docker rm postfix-relay
docker rmi local/docker-postfix:beta
docker build . -t local/docker-postfix:beta
docker compose -f .\docker-compose.production.yaml up -d