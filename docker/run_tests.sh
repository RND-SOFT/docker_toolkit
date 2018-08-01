#!/bin/sh

trap './down.sh' EXIT

docker-compose up -d --force-recreate --build || exit 1
docker-compose exec -T tests bundle exec rspec $@

code=$?
if [ $code -ne 0 ]; then
  docker-compose logs
fi

exit $code