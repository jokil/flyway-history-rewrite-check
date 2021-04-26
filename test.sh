#!/usr/bin/env bash

set -e

function prepare_test_db() {
  docker-compose --env-file=.env.test \
    -f docker-compose-test.yml \
    up -d \
    --force-recreate \
    --renew-anon-volumes &>/dev/null

  echo "Test docker-compose created"
  expect <<EOF &>/dev/null
set timeout -1

spawn docker-compose -f docker-compose-test.yml logs -f
expect "test_target_flyway exited with code 0"
EOF
  echo "Test flyway completed"
}
export TARGET_MIGRATION_DIRECTORY=./test1-target-migrations
prepare_test_db
if ./check.sh .env.test; then
  echo "Test 1 failed"
  exit 1
fi

export TARGET_MIGRATION_DIRECTORY=./test2-target-migrations
prepare_test_db
if ! ./check.sh .env.test; then
  echo "Test 2 failed"
  exit 1
fi

echo "All tests passed!"
docker-compose -f docker-compose-test.yml down &>/dev/null