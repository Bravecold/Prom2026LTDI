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

El frontend se publica como Azure Storage Static Website y consume la API desplegada en Azure Container Apps. El script genera `config.js` con `API_BASE_URL`, sube los archivos al contenedor `$web` y elimina el Container App frontend anterior después de confirmar la carga. Requiere Azure CLI autenticado con `az login` y permisos para crear recursos en la suscripcion.

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

La plantilla en `infra/main.bicep` crea el sitio estático, el entorno de Container Apps, Log Analytics, la API, PostgreSQL y Blob Storage. El script entrega al final la URL pública del Storage Website. El registro Basic, Container Apps, PostgreSQL y Storage generan costos según consumo; revisa precios y cuotas de la suscripcion antes de ejecutar.

## API y base de datos

La API inicial vive en `backend/`. Tiene estos recursos:

- `POST /api/auth/register`, `POST /api/auth/login` y `GET /api/auth/me`.
- El registro crea una solicitud pendiente; `is_approved` debe ser habilitado por el colegio antes de permitir el acceso.
- El ingreso requiere el correo completo usado durante el registro; `fcampo` por sí solo no es un correo válido.
- `GET /api/admin/pending-users` y `POST /api/admin/users/{id}/approve` permiten revisar y aprobar solicitudes usando el header `X-Admin-Token`.
- `GET /api/students?classroom=11A`.
- `POST /api/photos` con multipart (`file`, `student_id`, `caption`), limitado a imágenes de 10 MB.
- `GET/POST /api/photos/{photo_id}/comments`; publicar requiere JWT y el texto admite máximo 280 caracteres.
- `GET /api/health`.

Para desarrollo local, con Docker instalado:

```bash
docker compose up --build
```

La documentación interactiva queda en `http://localhost:8000/docs`. Al iniciar, SQLAlchemy crea las tablas `users`, `students`, `photos` y `comments`, y agrega el campo de aprobación si la base ya existía; esto es un bootstrap local. Antes de producción conviene sustituirlo por migraciones versionadas y agregar un rol de moderador para aprobar fotos y comentarios.

En Azure, la API debe desplegarse como un segundo Container App con `DATABASE_URL` apuntando a Azure Database for PostgreSQL Flexible Server y `AZURE_STORAGE_CONNECTION_STRING` almacenada como secreto. No se deben subir contraseñas al repositorio; para producción se recomienda Azure Key Vault y un dominio institucional.

Para desplegar o actualizar la API con el flujo de aprobación, define el token administrativo directamente en tu terminal y no lo guardes en el repositorio:

```bash
export AZURE_ADMIN_APPROVAL_TOKEN='un-token-largo-y-secreto'
./deploy-azure.sh
```

Después de desplegar, la solicitud se consulta con `GET /api/admin/pending-users` y se aprueba con `POST /api/admin/users/{id}/approve`, enviando `X-Admin-Token`. Actualmente no hay notificación por correo; la bandeja de solicitudes es la API administrativa.
