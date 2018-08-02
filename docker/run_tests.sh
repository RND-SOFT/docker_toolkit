#!/bin/sh
SELF=$(readlink -f $0)
export ENV_ROOT=$(dirname "${SELF}")

trap '$ENV_ROOT/down.sh' EXIT

cd $ENV_ROOT

docker-compose up -d --force-recreate --build || exit 1
docker-compose exec -T tests bundle exec rspec $@

code=$?
if [ $code -ne 0 ]; then
  docker-compose logs
fi

exit $code