#!/bin/bash

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>log.out 2>&1


echo "TEST=TRUE" >> /home/ubuntu/app/.env
echo "GITHUB_TOKEN=${GITHUB_TOKEN}" >> /home/ubuntu/app/.env

echo "DB_CONNECTION=${DB_CONNECTION}" >> /home/ubuntu/app/.env
echo "DB_HOST=${DB_HOST}" >> /home/ubuntu/app/.env
echo "DB_PORT=${DB_PORT}" >> /home/ubuntu/app/.env
echo "DB_DATABASE=${DB_DATABASE}" >> /home/ubuntu/app/.env
echo "DB_USERNAME=${DB_USERNAME}" >> /home/ubuntu/app/.env
echo "DB_PASSWORD=${DB_PASSWORD}" >> /home/ubuntu/app/.env

echo "REDIS_HOST=${REDIS_HOST}" >> /home/ubuntu/app/.env

echo "${COMPOSE}" > /home/ubuntu/app/docker-compose.yml

export GITHUB_TOKEN="${GITHUB_TOKEN}"

echo "${GITHUB_TOKEN}" | sudo docker login ghcr.io -u Markopteryx --password-stdin

sudo docker-compose -f /home/ubuntu/app/docker-compose.yml --env-file /home/ubuntu/app/.env up -d
