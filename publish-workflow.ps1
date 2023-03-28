param(
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Versionning)

docker tag aafloriangaudin/docker-postfix:latest aafloriangaudin/docker-postfix:$Versionning
docker tag local/docker-postfix:beta aafloriangaudin/docker-postfix:latest

docker push aafloriangaudin/docker-postfix:$Versionning
docker push aafloriangaudin/docker-postfix:latest