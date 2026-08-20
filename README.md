# Prom2026LTDI

Anuario digital de la Promocion 2026 del Liceo Campestre Thomas de Iriarte.

## Prototipo actual

La primera version es una experiencia web estatica en `index.html`, `styles.css` y `script.js`.
Incluye la galeria por curso, busqueda, ficha individual, contador de recuerdos, modal de registro para comentar y un formulario de aporte de fotos/recuerdos.

## Siguiente arquitectura

- Frontend: llevar estos componentes a una app web con estado del servidor.
- API Python: FastAPI para estudiantes, fotos, recuerdos, comentarios y autenticacion.
- Persistencia: PostgreSQL con usuarios, estudiantes, fotos, comentarios y moderacion.
- Archivos: almacenamiento local para desarrollo o Azure Blob Storage para fotos originales.
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

## API y base de datos

La API inicial vive en `backend/`. Tiene estos recursos:

- `POST /api/auth/register`, `POST /api/auth/login` y `GET /api/auth/me`.
- `GET /api/students?classroom=11A`.
- `POST /api/photos` con multipart (`file`, `student_id`, `caption`), limitado a imágenes de 10 MB.
- `GET/POST /api/photos/{photo_id}/comments`; publicar requiere JWT y el texto admite máximo 280 caracteres.
- `GET /api/health`.

Para desarrollo local, con Docker instalado:

```bash
docker compose up --build
```

La documentación interactiva queda en `http://localhost:8000/docs`. Al iniciar, SQLAlchemy crea las tablas `users`, `students`, `photos` y `comments`; esto es un bootstrap local. Antes de producción conviene sustituirlo por migraciones versionadas y agregar un rol de moderador para aprobar fotos y comentarios.

En Azure, la API debe desplegarse como un segundo Container App con `DATABASE_URL` apuntando a Azure Database for PostgreSQL Flexible Server y `AZURE_STORAGE_CONNECTION_STRING` almacenada como secreto. No se deben subir contraseñas al repositorio; para producción se recomienda Azure Key Vault y un dominio institucional.
