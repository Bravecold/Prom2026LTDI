#!/usr/bin/env bash
set -euo pipefail

LOCATION="${AZURE_LOCATION:-eastus}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-prom2026lcti-rg}"
REGISTRY="${AZURE_CONTAINER_REGISTRY:-prom2026lcti}"
APP_NAME="${AZURE_CONTAINER_APP:-prom2026lcti}"
IMAGE_TAG="${IMAGE_TAG:-v$(date +%Y%m%d%H%M%S)}"

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

echo "Construyendo y publicando ${IMAGE}..."
az acr build --registry "$REGISTRY" --image "$IMAGE" .

ACR_USERNAME="$(az acr credential show --name "$REGISTRY" --query username --output tsv)"
ACR_PASSWORD="$(az acr credential show --name "$REGISTRY" --query 'passwords[0].value' --output tsv)"

echo "Publicando Azure Container App..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters appName="$APP_NAME" containerImage="$IMAGE" acrLoginServer="$REGISTRY_SERVER" acrUsername="$ACR_USERNAME" acrPassword="$ACR_PASSWORD" \
  --query properties.outputs.siteUrl.value \
  --output tsv