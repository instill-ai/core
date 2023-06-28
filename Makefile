.DEFAULT_GOAL:=help

#============================================================================

# load environment variables
include .env
export

COMPOSE_FILES := -f docker-compose.yml
ifeq (${OBSERVE_ENABLED}, true)
	COMPOSE_FILES := ${COMPOSE_FILES} -f docker-compose.observe.yml
endif

UNAME_S := $(shell uname -s)

CONTAINER_BUILD_NAME := base-build
CONTAINER_COMPOSE_IMAGE_NAME := instill/base-compose
CONTAINER_PLAYWRIGHT_IMAGE_NAME := instill/base-console-playwright
CONTAINER_BACKEND_INTEGRATION_TEST_NAME := base-backend-integration-test
CONTAINER_CONSOLE_INTEGRATION_TEST_NAME := base-console-integration-test

HELM_NAMESPACE := instill-ai
HELM_RELEASE_NAME := base

#============================================================================

.PHONY: all
all:			## Launch all services with their up-to-date release version
	@EDITION=local-ce docker compose ${COMPOSE_FILES} up -d --quiet-pull
	@EDITION=local-ce docker compose ${COMPOSE_FILES} rm -f

.PHONY: latest
latest:			## Lunch all dependent services with their latest codebase
	@COMPOSE_PROFILES=$(PROFILE) EDITION=local-ce:latest docker compose ${COMPOSE_FILES} -f docker-compose.latest.yml up -d --quiet-pull
	@COMPOSE_PROFILES=$(PROFILE) EDITION=local-ce:latest docker compose ${COMPOSE_FILES} -f docker-compose.latest.yml rm -f

.PHONY: logs
logs:			## Tail all logs with -n 10
	@docker compose logs --follow --tail=10

.PHONY: pull
pull:			## Pull all service images
	@docker compose pull

.PHONY: stop
stop:			## Stop all components
	@docker compose stop

.PHONY: start
start:			## Start all stopped services
	@docker compose start

.PHONY: restart
restart:		## Restart all services
	@docker compose restart

.PHONY: rm
rm:				## Remove all stopped service containers
	@docker compose rm -f

.PHONY: down
down:			## Stop all services and remove all service containers and volumes
	@docker rm -f ${CONTAINER_BUILD_NAME}-latest >/dev/null 2>&1
	@docker rm -f ${CONTAINER_BUILD_NAME}-release >/dev/null 2>&1
	@docker rm -f ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-latest >/dev/null 2>&1
	@docker rm -f ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-latest >/dev/null 2>&1
	@docker rm -f ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-release >/dev/null 2>&1
	@docker rm -f ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-release >/dev/null 2>&1
	@docker rm -f ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-latest >/dev/null 2>&1
	@docker rm -f ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-helm-latest >/dev/null 2>&1
	@docker rm -f ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-release >/dev/null 2>&1
	@docker rm -f ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-helm-latest >/dev/null 2>&1
	@docker compose -f docker-compose.yml -f docker-compose.observe.yml down -v

.PHONY: images
images:			## List all container images
	@docker compose images

.PHONY: ps
ps:				## List all service containers
	@docker compose ps

.PHONY: top
top:			## Display all running service processes
	@docker compose top

.PHONY: doc
doc:						## Run Redoc for OpenAPI spec at http://localhost:3001
	@docker compose up -d redoc_openapi

.PHONY: build-latest
build-latest:				## Build latest images for all Instill Base components
	@docker build --progress plain \
		--build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
		--build-arg GOLANG_VERSION=${GOLANG_VERSION} \
		--build-arg K6_VERSION=${K6_VERSION} \
		--build-arg CACHE_DATE="$(shell date)" \
		--target latest \
		-t ${CONTAINER_COMPOSE_IMAGE_NAME}:latest .
	@docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v ${BUILD_CONFIG_DIR_PATH}/.env:/instill-ai/base/.env \
		-v ${BUILD_CONFIG_DIR_PATH}/docker-compose.build.yml:/instill-ai/base/docker-compose.build.yml \
		--name ${CONTAINER_BUILD_NAME}-latest \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			API_GATEWAY_VERSION=latest \
			MGMT_BACKEND_VERSION=latest \
			CONSOLE_VERSION=latest \
			docker compose -f docker-compose.build.yml build --progress plain \
		"

.PHONY: build-release
build-release:				## Build release images for all Instill Base components
	@docker build --progress plain \
		--build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
		--build-arg GOLANG_VERSION=${GOLANG_VERSION} \
		--build-arg K6_VERSION=${K6_VERSION} \
		--build-arg CACHE_DATE="$(shell date)" \
		--build-arg API_GATEWAY_VERSION=${API_GATEWAY_VERSION} \
		--build-arg MGMT_BACKEND_VERSION=${MGMT_BACKEND_VERSION} \
		--build-arg CONSOLE_VERSION=${CONSOLE_VERSION} \
		--target release \
		-t ${CONTAINER_COMPOSE_IMAGE_NAME}:release .
	@docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v ${BUILD_CONFIG_DIR_PATH}/.env:/instill-ai/base/.env \
		-v ${BUILD_CONFIG_DIR_PATH}/docker-compose.build.yml:/instill-ai/base/docker-compose.build.yml \
		--name ${CONTAINER_BUILD_NAME}-release \
		${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			API_GATEWAY_VERSION=${API_GATEWAY_VERSION} \
			MGMT_BACKEND_VERSION=${MGMT_BACKEND_VERSION} \
			CONSOLE_VERSION=${CONSOLE_VERSION} \
			docker compose -f docker-compose.build.yml build --progress plain \
		"

.PHONY: integration-test-latest
integration-test-latest:			## Run integration test on the latest Instill Base
	@make build-latest
	@COMPOSE_PROFILES=all EDITION=local-ce:test ITMODE_ENABLED=true docker compose -f docker-compose.yml -f docker-compose.latest.yml up -d --quiet-pull
	@COMPOSE_PROFILES=all EDITION=local-ce:test docker compose -f docker-compose.yml -f docker-compose.latest.yml rm -f
	@docker run -it --rm \
		--network instill-network \
		--name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-latest \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			/bin/bash -c 'cd mgmt-backend && make integration-test API_GATEWAY_HOST=${API_GATEWAY_HOST} API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@make down

.PHONY: integration-test-release
integration-test-release:			## Run integration test on the release Instill Base
	@make build-release
	@EDITION=local-ce:test ITMODE_ENABLED=true docker compose up -d --quiet-pull
	@EDITION=local-ce:test docker compose rm -f
	@docker run -it --rm \
		--network instill-network \
		--name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-release \
		${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			/bin/bash -c 'cd mgmt-backend && make integration-test API_GATEWAY_HOST=${API_GATEWAY_HOST} API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@make down

.PHONY: helm-integration-test-latest
helm-integration-test-latest:                       ## Run integration test on the Helm latest for Instill Base
ifeq ($(UNAME_S),Darwin)
	@make build-latest
	@helm install ${HELM_RELEASE_NAME} charts/base --devel --namespace instill-ai --create-namespace \
		--set itMode=true \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=latest \
		--set mgmt.image.tag=latest \
		--set console.image.tag=latest \
		--set tags.observability=false \
		--set apigatewayURL=http://host.docker.internal:${API_GATEWAY_PORT}
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm -p ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} --name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-latest ${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			/bin/bash -c 'cd mgmt-backend && make integration-test API_GATEWAY_HOST=host.docker.internal API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@helm uninstall ${HELM_RELEASE_NAME} --namespace instill-ai
	@kubectl delete namespace instill-ai
	@pkill -f "port-forward"
	@make down
endif
ifeq ($(UNAME_S),Linux)
	@make build-latest
	@helm install ${HELM_RELEASE_NAME} charts/base --devel --namespace instill-ai --create-namespace \
		--set itMode=true \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=latest \
		--set mgmt.image.tag=latest \
		--set console.image.tag=latest \
		--set tags.observability=false \
		--set apigatewayURL=http://localhost:${API_GATEWAY_PORT}
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm --network host --name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-latest ${CONTAINER_COMPOSE_IMAGE_NAME}:latest /bin/bash -c " \
			/bin/bash -c 'cd mgmt-backend && make integration-test API_GATEWAY_HOST=localhost API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@helm uninstall ${HELM_RELEASE_NAME} --namespace instill-ai
	@kubectl delete namespace instill-ai
	@pkill -f "port-forward"
	@make down
endif

.PHONY: helm-integration-test-release
helm-integration-test-release:                       ## Run integration test on the Helm release for Instill Base
ifeq ($(UNAME_S),Darwin)
	@make build-release
	@helm install ${HELM_RELEASE_NAME} charts/base --devel --namespace instill-ai --create-namespace \
		--set itMode=true \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=${API_GATEWAY_VERSION} \
		--set mgmt.image.tag=${MGMT_BACKEND_VERSION} \
		--set console.image.tag=${CONSOLE_VERSION} \
		--set tags.observability=false \
		--set apigatewayURL=http://host.docker.internal:${API_GATEWAY_PORT}
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm -p ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} --name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-release ${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			/bin/bash -c 'cd mgmt-backend && make integration-test API_GATEWAY_HOST=host.docker.internal API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@helm uninstall ${HELM_RELEASE_NAME} --namespace instill-ai
	@kubectl delete namespace instill-ai
	@pkill -f "port-forward"
	@make down
endif
ifeq ($(UNAME_S),Linux)
	@make build-release
	@helm install ${HELM_RELEASE_NAME} charts/base --devel --namespace instill-ai --create-namespace \
		--set itMode=true \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=${API_GATEWAY_VERSION} \
		--set mgmt.image.tag=${MGMT_BACKEND_VERSION} \
		--set console.image.tag=${CONSOLE_VERSION} \
		--set tags.observability=false \
		--set apigatewayURL=http://localhost:${API_GATEWAY_PORT}
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm --network host --name ${CONTAINER_BACKEND_INTEGRATION_TEST_NAME}-helm-release ${CONTAINER_COMPOSE_IMAGE_NAME}:release /bin/bash -c " \
			/bin/bash -c 'cd mgmt-backend && make integration-test API_GATEWAY_HOST=localhost API_GATEWAY_PORT=${API_GATEWAY_PORT}' \
		"
	@helm uninstall ${HELM_RELEASE_NAME} --namespace instill-ai
	@kubectl delete namespace instill-ai
	@pkill -f "port-forward"
	@make down
endif

# ==================================================================
# ==================== Console Integration Test ====================
# ==================================================================

.PHONY: console-integration-test-latest
console-integration-test-latest:			## Run console integration test on the latest Instill Base
	@make build-latest
	@COMPOSE_PROFILES=all EDITION=local-ce:test ITMODE_ENABLED=true docker compose -f docker-compose.yml -f docker-compose.latest.yml up -d --quiet-pull
	@COMPOSE_PROFILES=all EDITION=local-ce:test docker compose -f docker-compose.yml -f docker-compose.latest.yml rm -f
	@docker run -it --rm \
		-e NEXT_PUBLIC_CONSOLE_BASE_URL=http://console:3000 \
		-e NEXT_PUBLIC_API_GATEWAY_BASE_URL=http://api-gateway:${API_GATEWAY_PORT}  \
		-e NEXT_PUBLIC_API_VERSION=v1alpha \
		-e NEXT_PUBLIC_SELF_SIGNED_CERTIFICATION=false \
		-e NEXT_PUBLIC_INSTILL_AI_USER_COOKIE_NAME=instill-ai-user \
		-e NEXT_PUBLIC_CONSOLE_EDITION=local-ce:test \
		--network instill-network \
		--entrypoint ./entrypoint-playwright.sh \
		--name ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-latest \
		${CONTAINER_PLAYWRIGHT_IMAGE_NAME}:latest
	@make down

.PHONY: console-integration-test-release
console-integration-test-release:			## Run console integration test on the release Instill Base
	@make build-release
	@EDITION=local-ce:test ITMODE_ENABLED=true \
		docker compose up -d --quiet-pull
	@EDITION=local-ce:test docker compose rm -f
	@docker run -it --rm \
		-e NEXT_PUBLIC_CONSOLE_BASE_URL=http://console:3000 \
		-e NEXT_PUBLIC_API_GATEWAY_BASE_URL=http://api-gateway:${API_GATEWAY_PORT}  \
		-e NEXT_PUBLIC_API_VERSION=v1alpha \
		-e NEXT_PUBLIC_SELF_SIGNED_CERTIFICATION=false \
		-e NEXT_PUBLIC_INSTILL_AI_USER_COOKIE_NAME=instill-ai-user \
		-e NEXT_PUBLIC_CONSOLE_EDITION=local-ce:test \
		--network instill-network \
		--entrypoint ./entrypoint-playwright.sh \
		--name ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-release \
		${CONTAINER_PLAYWRIGHT_IMAGE_NAME}:${CONSOLE_VERSION}
	@make down

.PHONY: console-helm-integration-test-latest
console-helm-integration-test-latest:                       ## Run console integration test on the Helm latest for Instill Base
ifeq ($(UNAME_S),Darwin)
	@make build-latest
	@helm install ${HELM_RELEASE_NAME} charts/base --devel --namespace instill-ai --create-namespace \
		--set itMode=true \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=latest \
		--set mgmt.image.tag=latest \
		--set console.image.tag=latest \
		--set apigatewayURL=http://host.docker.internal:${API_GATEWAY_PORT}
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm \
		-e NEXT_PUBLIC_CONSOLE_BASE_URL=http://host.docker.internal:3000 \
		-e NEXT_PUBLIC_API_GATEWAY_BASE_URL=http://host.docker.internal:${API_GATEWAY_PORT} \
		-e NEXT_PUBLIC_API_VERSION=v1alpha \
		-e NEXT_PUBLIC_SELF_SIGNED_CERTIFICATION=false \
		-e NEXT_PUBLIC_INSTILL_AI_USER_COOKIE_NAME=instill-ai-user \
		-e NEXT_PUBLIC_CONSOLE_EDITION=k8s-ce:test \
		-p ${API_GATEWAY_PORT} :${API_GATEWAY_PORT}  \
		-p 3000:3000 \
		--entrypoint ./entrypoint-playwright.sh \
		--name ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-latest \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest
	@helm uninstall ${HELM_RELEASE_NAME} --namespace instill-ai
	@kubectl delete namespace instill-ai
	@pkill -f "port-forward"
	@make down
endif
ifeq ($(UNAME_S),Linux)
	@make build-latest
	@helm install ${HELM_RELEASE_NAME} charts/base --devel --namespace instill-ai --create-namespace \
		--set itMode=true \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=latest \
		--set mgmt.image.tag=latest \
		--set apigatewayURL=http://localhost:${API_GATEWAY_PORT}
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm \
		-e NEXT_PUBLIC_CONSOLE_BASE_URL=http://localhost:3000 \
		-e NEXT_PUBLIC_API_GATEWAY_BASE_URL=http://localhost:${API_GATEWAY_PORT}  \
		-e NEXT_PUBLIC_API_VERSION=v1alpha \
		-e NEXT_PUBLIC_SELF_SIGNED_CERTIFICATION=false \
		-e NEXT_PUBLIC_INSTILL_AI_USER_COOKIE_NAME=instill-ai-user \
		-e NEXT_PUBLIC_CONSOLE_EDITION=k8s-ce:test \
		--network host \
		--entrypoint ./entrypoint-playwright.sh \
		--name ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-latest \
		${CONTAINER_COMPOSE_IMAGE_NAME}:latest
	@helm uninstall ${HELM_RELEASE_NAME} --namespace instill-ai
	@kubectl delete namespace instill-ai
	@pkill -f "port-forward"
	@make down
endif

.PHONY: console-helm-integration-test-release
console-helm-integration-test-release:                       ## Run console integration test on the Helm release for Instill Base
ifeq ($(UNAME_S),Darwin)
	@make build-release
	@helm install ${HELM_RELEASE_NAME} charts/base --devel --namespace instill-ai --create-namespace \
		--set itMode=true \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=${API_GATEWAY_VERSION} \
		--set mgmt.image.tag=${MGMT_BACKEND_VERSION} \
		--set console.image.tag=${CONSOLE_VERSION} \
		--set apigatewayURL=http://host.docker.internal:${API_GATEWAY_PORT}
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm \
		-e NEXT_PUBLIC_CONSOLE_BASE_URL=http://host.docker.internal:3000 \
		-e NEXT_PUBLIC_API_GATEWAY_BASE_URL=http://host.docker.internal:${API_GATEWAY_PORT}  \
		-e NEXT_PUBLIC_API_VERSION=v1alpha \
		-e NEXT_PUBLIC_SELF_SIGNED_CERTIFICATION=false \
		-e NEXT_PUBLIC_INSTILL_AI_USER_COOKIE_NAME=instill-ai-user \
		-e NEXT_PUBLIC_CONSOLE_EDITION=k8s-ce:test \
		-p ${API_GATEWAY_PORT} :${API_GATEWAY_PORT}  \
		-p 3000:3000 \
		--entrypoint ./entrypoint-playwright.sh \
		--name ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-release \
		${CONTAINER_COMPOSE_IMAGE_NAME}:${CONSOLE_VERSION}
	@helm uninstall ${HELM_RELEASE_NAME} --namespace instill-ai
	@kubectl delete namespace instill-ai
	@pkill -f "port-forward"
	@make down
endif
ifeq ($(UNAME_S),Linux)
	@make build-release
	@helm install ${HELM_RELEASE_NAME} charts/base --devel --namespace instill-ai --create-namespace \
		--set itMode=true \
		--set edition=k8s-ce:test \
		--set apigateway.image.tag=${API_GATEWAY_VERSION} \
		--set mgmt.image.tag=${MGMT_BACKEND_VERSION} \
		--set console.image.tag=${CONSOLE_VERSION} \
		--set apigatewayURL=http://localhost:${API_GATEWAY_PORT}
	@kubectl rollout status deployment base-apigateway -n instill-ai --timeout=120s
	@export APIGATEWAY_POD_NAME=$$(kubectl get pods --namespace instill-ai -l "app.kubernetes.io/component=api-gateway,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath="{.items[0].metadata.name}") && \
		kubectl --namespace instill-ai port-forward $${APIGATEWAY_POD_NAME} ${API_GATEWAY_PORT}:${API_GATEWAY_PORT} > /dev/null 2>&1 &
	@while ! nc -vz localhost ${API_GATEWAY_PORT} > /dev/null 2>&1; do sleep 1; done
	@docker run -it --rm \
		-e NEXT_PUBLIC_CONSOLE_BASE_URL=http://localhost:3000 \
		-e NEXT_PUBLIC_API_GATEWAY_BASE_URL=http://localhost:${API_GATEWAY_PORT}  \
		-e NEXT_PUBLIC_API_VERSION=v1alpha \
		-e NEXT_PUBLIC_SELF_SIGNED_CERTIFICATION=false \
		-e NEXT_PUBLIC_INSTILL_AI_USER_COOKIE_NAME=instill-ai-user \
		-e NEXT_PUBLIC_CONSOLE_EDITION=k8s-ce:test \
		--network host \
		--entrypoint ./entrypoint-playwright.sh \
		--name ${CONTAINER_CONSOLE_INTEGRATION_TEST_NAME}-release \
		${CONTAINER_COMPOSE_IMAGE_NAME}:${CONSOLE_VERSION}
	@helm uninstall ${HELM_RELEASE_NAME} --namespace instill-ai
	@kubectl delete namespace instill-ai
	@pkill -f "port-forward"
	@make down
endif

.PHONY: help
help:       	## Show this help
	@echo "\nMake Application with Docker Compose"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m (default: help)\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)