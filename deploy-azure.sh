#!/usr/bin/env bash
set -euo pipefail

LOCATION="${AZURE_LOCATION:-eastus}"
DATABASE_LOCATION="${AZURE_DATABASE_LOCATION:-centralus}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-prom2026lcti-rg}"
REGISTRY="${AZURE_CONTAINER_REGISTRY:-prom2026lcti}"
APP_NAME="${AZURE_CONTAINER_APP:-prom2026lcti}"
IMAGE_TAG="${IMAGE_TAG:-v$(date +%Y%m%d%H%M%S)}"
POSTGRES_ADMIN="${AZURE_POSTGRES_ADMIN:-promadmin}"
POSTGRES_PASSWORD="${AZURE_POSTGRES_PASSWORD:-$(openssl rand -hex 24)}"
JWT_SECRET="${AZURE_JWT_SECRET:-$(openssl rand -hex 32)}"

command -v az >/dev/null || { echo "Azure CLI (az) es requerido." >&2; exit 1; }

echo "Creando o actualizando el grupo de recursos..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

echo "Creando el registro de contenedores..."
az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$REGISTRY" \
  --sku Basic \
  --admin-enabled true \
  --output none

REGISTRY_SERVER="$(az acr show --name "$REGISTRY" --query loginServer --output tsv)"
IMAGE="${REGISTRY_SERVER}/${APP_NAME}:${IMAGE_TAG}"

API_IMAGE="${REGISTRY_SERVER}/${APP_NAME}-api:${IMAGE_TAG}"

echo "Construyendo y publicando ${IMAGE}..."
az acr build --registry "$REGISTRY" --image "$IMAGE" .
az acr build --registry "$REGISTRY" --image "$API_IMAGE" --file backend/Dockerfile .

ACR_USERNAME="$(az acr credential show --name "$REGISTRY" --query username --output tsv)"
ACR_PASSWORD="$(az acr credential show --name "$REGISTRY" --query 'passwords[0].value' --output tsv)"
FRONTEND_URL="https://$(az containerapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn --output tsv)"

echo "Publicando Azure Container App..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters appName="$APP_NAME" location="$LOCATION" databaseLocation="$DATABASE_LOCATION" containerImage="$IMAGE" apiImage="$API_IMAGE" acrLoginServer="$REGISTRY_SERVER" acrUsername="$ACR_USERNAME" acrPassword="$ACR_PASSWORD" postgresAdminUser="$POSTGRES_ADMIN" postgresAdminPassword="$POSTGRES_PASSWORD" jwtSecret="$JWT_SECRET" frontendUrl="$FRONTEND_URL" \
  --query properties.outputs \
  --output json