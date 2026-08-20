# Prom2026LTDI

Anuario digital de la Promocion 2026 del Liceo Campestre Thomas de Iriarte.

## Prototipo actual

La primera version es una experiencia web estatica en `index.html`, `styles.css` y `script.js`.
Incluye la galeria por curso, busqueda, ficha individual, contador de recuerdos, modal de registro para comentar y un formulario de aporte de fotos/recuerdos.

## Siguiente arquitectura

- Frontend: llevar estos componentes a una app web con estado del servidor.
- API Python: FastAPI para estudiantes, fotos, recuerdos, comentarios y autenticacion.
- Persistencia: PostgreSQL con migraciones y roles de moderacion.
- Archivos: almacenamiento de objetos compatible con S3 para fotos originales y thumbnails.
- Despliegue: contenedores separados para web, API y base de datos en un PaaS.

Los comentarios deben pasar por moderacion y los perfiles de estudiantes requieren autorizacion del colegio y tratamiento de datos acorde con la politica institucional.

## Despliegue en Azure

El prototipo se puede publicar como contenedor en Azure Container Apps usando Azure Container Registry. Requiere Azure CLI autenticado con `az login` y permisos para crear recursos en la suscripcion.

```bash
az login
az account set --subscription "NOMBRE_O_ID_DE_LA_SUSCRIPCION"
chmod +x deploy-azure.sh
./deploy-azure.sh
```

Se pueden personalizar los valores sin editar archivos:

```bash
AZURE_LOCATION=centralus \\
AZURE_RESOURCE_GROUP=prom2026lcti-rg \\
AZURE_CONTAINER_REGISTRY=prom2026lcti \\
AZURE_CONTAINER_APP=prom2026lcti \\
./deploy-azure.sh
```

La plantilla en `infra/main.bicep` crea el entorno de Container Apps, Log Analytics y la aplicación web con HTTPS. El script entrega al final la URL pública. El registro Basic y Container Apps generan costos según consumo; revisa precios y cuotas de la suscripción antes de ejecutar.

PostgreSQL se añadirá junto con la API FastAPI: este prototipo aún no tiene endpoints ni migraciones, por lo que aprovisionar una base ahora dejaría un recurso con costo sin consumidor. Para producción también habrá que mover las credenciales a Azure Key Vault y activar un dominio institucional.
