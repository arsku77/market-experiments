up: docker-up
down: docker-down
restart: docker-down docker-up
init: docker-down-clear market-clear docker-pull docker-build docker-up market-init
test: market-test
test-coverage: market-test-coverage
test-unit: market-test-unit
test-unit-coverage: market-test-unit-coverage
dump: app-dump-all
dump-one: app-dump-one
restore: app-restore-all


docker-up:
	docker-compose up -d

docker-down:
	docker-compose down --remove-orphans

docker-down-clear:
	docker-compose down -v --remove-orphans

docker-pull:
	docker-compose pull

docker-build:
	docker-compose build

#market-init: market-composer-install market-assets-install market-oauth-keys market-wait-db create-maildb market-wait-maildb market-migrations market-fixtures market-ready
market-init: market-composer-install market-assets-install market-oauth-keys market-wait-db market-migrations market-fixtures market-ready

market-clear:
	docker run --rm -v ${PWD}/market:/app --workdir=/app alpine rm -f .ready

market-composer-install:
	docker-compose run --rm market-php-cli composer install

market-assets-install:
	docker-compose run --rm market-node yarn install
	docker-compose run --rm market-node npm rebuild node-sass

market-oauth-keys:
	docker-compose run --rm market-php-cli mkdir -p var/oauth
	docker-compose run --rm market-php-cli openssl genrsa -out var/oauth/private.key 2048
	docker-compose run --rm market-php-cli openssl rsa -in var/oauth/private.key -pubout -out var/oauth/public.key
	docker-compose run --rm market-php-cli chmod 644 var/oauth/private.key var/oauth/public.key

market-wait-db:
	until docker-compose exec -T market-postgres pg_isready --timeout=0 --dbname=marketdb ; do sleep 1 ; done

market-wait-maildb:
	until docker-compose exec -T market-postgres pg_isready --timeout=0 --dbname=roundcube ; do sleep 1 ; done

market-migrations:
	docker-compose run --rm market-php-cli php bin/console doctrine:migrations:migrate --no-interaction

market-fixtures:
	docker-compose run --rm market-php-cli php bin/console doctrine:fixtures:load --no-interaction

market-ready:
	docker run --rm -v ${PWD}/market:/app --workdir=/app alpine touch .ready

market-assets-dev:
	docker-compose run --rm market-node npm run dev

market-test:
	docker-compose run --rm market-php-cli php bin/phpunit

market-test-coverage:
	docker-compose run --rm market-php-cli php bin/phpunit --coverage-clover var/clover.xml --coverage-html var/coverage

market-test-unit:
	docker-compose run --rm market-php-cli php bin/phpunit --testsuite=unit

market-test-unit-coverage:
	docker-compose run --rm market-php-cli php bin/phpunit --testsuite=unit --coverage-clover var/clover.xml --coverage-html var/coverage

build-production:
	docker build --pull --file=market/docker/production/nginx.docker --tag ${REGISTRY_ADDRESS}/market-nginx:${IMAGE_TAG} market
	docker build --pull --file=market/docker/production/php-fpm.docker --tag ${REGISTRY_ADDRESS}/market-php-fpm:${IMAGE_TAG} market
	docker build --pull --file=market/docker/production/php-cli.docker --tag ${REGISTRY_ADDRESS}/market-php-cli:${IMAGE_TAG} market
	docker build --pull --file=market/docker/production/postgres.docker --tag ${REGISTRY_ADDRESS}/market-postgres:${IMAGE_TAG} market
	docker build --pull --file=market/docker/production/redis.docker --tag ${REGISTRY_ADDRESS}/market-redis:${IMAGE_TAG} market
	docker build --pull --file=storage/docker/production/nginx.docker --tag ${REGISTRY_ADDRESS}/storage-nginx:${IMAGE_TAG} storage
	docker build --pull --file=centrifugo/docker/production/centrifugo.docker --tag ${REGISTRY_ADDRESS}/centrifugo:${IMAGE_TAG} centrifugo

push-production:
	docker push ${REGISTRY_ADDRESS}/market-nginx:${IMAGE_TAG}
	docker push ${REGISTRY_ADDRESS}/market-php-fpm:${IMAGE_TAG}
	docker push ${REGISTRY_ADDRESS}/market-php-cli:${IMAGE_TAG}
	docker push ${REGISTRY_ADDRESS}/market-postgres:${IMAGE_TAG}
	docker push ${REGISTRY_ADDRESS}/market-redis:${IMAGE_TAG}
	docker push ${REGISTRY_ADDRESS}/storage-nginx:${IMAGE_TAG}
	docker push ${REGISTRY_ADDRESS}/centrifugo:${IMAGE_TAG}

deploy-production:
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'rm -rf docker-compose.yml .env'
	scp -o StrictHostKeyChecking=no -P ${PRODUCTION_PORT} docker-compose-production.yml ${PRODUCTION_HOST}:docker-compose.yml
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "REGISTRY_ADDRESS=${REGISTRY_ADDRESS}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "IMAGE_TAG=${IMAGE_TAG}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "MARKET_APP_SECRET=${MARKET_APP_SECRET}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "MARKET_DB_PASSWORD=${MARKET_DB_PASSWORD}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "MARKET_REDIS_PASSWORD=${MARKET_REDIS_PASSWORD}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "MARKET_MAILER_URL=${MARKET_MAILER_URL}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "MARKET_OAUTH_FACEBOOK_SECRET=${MARKET_OAUTH_FACEBOOK_SECRET}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "STORAGE_BASE_URL=${STORAGE_BASE_URL}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "STORAGE_FTP_HOST=${STORAGE_FTP_HOST}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "STORAGE_FTP_USERNAME=${STORAGE_FTP_USERNAME}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "STORAGE_FTP_PASSWORD=${STORAGE_FTP_PASSWORD}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "CENTRIFUGO_WS_HOST=${CENTRIFUGO_WS_HOST}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "CENTRIFUGO_API_KEY=${CENTRIFUGO_API_KEY}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'echo "CENTRIFUGO_SECRET=${CENTRIFUGO_SECRET}" >> .env'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'docker-compose pull'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'docker-compose up --build -d'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'until docker-compose exec -T market-postgres pg_isready --timeout=0 --dbname=app ; do sleep 1 ; done'
	ssh -o StrictHostKeyChecking=no ${PRODUCTION_HOST} -p ${PRODUCTION_PORT} 'docker-compose run --rm market-php-cli php bin/console doctrine:migrations:migrate --no-interaction'

app-dump-all:
	docker exec -t market-nw_market-postgres_1 pg_dumpall -c -U app > /var/backups/projects/market-nw/dump_all_`date +%d-%m-%Y"_"%H_%M_%S`.sql

app-dump-one:
	docker exec -t market-nw_market-postgres_1 pg_dump -c -U app marketdb> /var/backups/projects/market-nw/dump_marketdb_`date +%d-%m-%Y"_"%H_%M_%S`.sql

app-restore-all:
	cat /var/backups/projects/market-nw/dump_all_10-09-2019_13_04_05.sql | docker exec -i market-nw_market-postgres_1 psql -U app -d marketdb

create-maildb:
	docker exec -t market-nw_market-postgres_1 psql -U app -d postgres -c "CREATE DATABASE roundcube;"
	docker exec -t market-nw_market-postgres_1 psql -U app -d postgres -c "CREATE USER roundcube SUPERUSER PASSWORD 'secretas';"
	docker exec -t market-nw_market-postgres_1 psql -U app -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE roundcube TO roundcube;"

start-email-server:
	docker exec -t market-nw_market-postgres_1 psql -U app -d postgres -c "CREATE DATABASE roundcube;"
	docker exec -t market-nw_market-postgres_1 psql -U app -d postgres -c "CREATE USER roundcube SUPERUSER PASSWORD 'secretas';"
	docker exec -t market-nw_market-postgres_1 psql -U app -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE roundcube TO roundcube;"
