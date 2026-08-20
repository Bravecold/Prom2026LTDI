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
ADMIN_APPROVAL_TOKEN="${AZURE_ADMIN_APPROVAL_TOKEN:-}"

if [[ -z "$ADMIN_APPROVAL_TOKEN" ]]; then
  echo "Define AZURE_ADMIN_APPROVAL_TOKEN antes de desplegar." >&2
  echo "Ejemplo: export AZURE_ADMIN_APPROVAL_TOKEN=un-token-largo-y-secreto" >&2
  exit 1
fi

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
API_IMAGE="${REGISTRY_SERVER}/${APP_NAME}-api:${IMAGE_TAG}"

echo "Construyendo y publicando ${API_IMAGE}..."
az acr build --registry "$REGISTRY" --image "$API_IMAGE" --file backend/Dockerfile .

ACR_USERNAME="$(az acr credential show --name "$REGISTRY" --query username --output tsv)"
ACR_PASSWORD="$(az acr credential show --name "$REGISTRY" --query 'passwords[0].value' --output tsv)"
STORAGE_NAME="${APP_NAME//-/}media"
FRONTEND_URL="$(az storage account show --name "$STORAGE_NAME" --resource-group "$RESOURCE_GROUP" --query primaryEndpoints.web --output tsv | sed 's:/$::')"
API_FQDN="$(az containerapp show --name "${APP_NAME}-api" --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn --output tsv)"
if [[ -z "$API_FQDN" ]]; then
  echo "No se pudo obtener la URL publica de la API." >&2
  exit 1
fi

echo "Publicando Azure Container App..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters appName="$APP_NAME" location="$LOCATION" databaseLocation="$DATABASE_LOCATION" apiImage="$API_IMAGE" acrLoginServer="$REGISTRY_SERVER" acrUsername="$ACR_USERNAME" acrPassword="$ACR_PASSWORD" postgresAdminUser="$POSTGRES_ADMIN" postgresAdminPassword="$POSTGRES_PASSWORD" jwtSecret="$JWT_SECRET" adminApprovalToken="$ADMIN_APPROVAL_TOKEN" frontendUrl="$FRONTEND_URL" \
  --query properties.outputs \
  --output json

TEMP_FRONTEND_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_FRONTEND_DIR"' EXIT
cp index.html styles.css script.js config.js "$TEMP_FRONTEND_DIR/"
printf "window.APP_CONFIG = { API_BASE_URL: '%s' };\n" "https://${API_FQDN}" > "$TEMP_FRONTEND_DIR/config.js"
STORAGE_KEY="$(az storage account keys list --account-name "$STORAGE_NAME" --resource-group "$RESOURCE_GROUP" --query '[0].value' --output tsv)"
az storage blob service-properties update --account-name "$STORAGE_NAME" --account-key "$STORAGE_KEY" --static-website --index-document index.html --404-document index.html --output none
az storage container create --name '$web' --account-name "$STORAGE_NAME" --account-key "$STORAGE_KEY" --public-access off --output none
az storage blob upload-batch --account-name "$STORAGE_NAME" --account-key "$STORAGE_KEY" --destination '$web' --source "$TEMP_FRONTEND_DIR" --overwrite true --output none
az containerapp delete --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --yes --output none 2>/dev/null || true
echo "Frontend estatico: ${FRONTEND_URL}"