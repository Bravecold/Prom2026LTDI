from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile

from .config import get_settings

MAX_PHOTO_BYTES = 10 * 1024 * 1024


async def save_photo(file: UploadFile) -> tuple[str, str]:
    settings = get_settings()
    extension = Path(file.filename or "photo.jpg").suffix.lower() or ".jpg"
    object_key = f"{uuid4().hex}{extension}"
    if settings.azure_storage_connection_string:
        from azure.storage.blob import BlobServiceClient, ContentSettings

        client = BlobServiceClient.from_connection_string(settings.azure_storage_connection_string)
        container = client.get_container_client(settings.azure_storage_container)
        if not container.exists():
            container.create_container()
        blob = container.get_blob_client(object_key)
        content = await file.read(MAX_PHOTO_BYTES + 1)
        if len(content) > MAX_PHOTO_BYTES:
            raise ValueError("La imagen supera el limite de 10 MB")
        blob.upload_blob(content, overwrite=False, content_settings=ContentSettings(content_type=file.content_type or "image/jpeg"))
        return object_key, blob.url

    directory = Path(settings.storage_directory)
    directory.mkdir(parents=True, exist_ok=True)
    destination = directory / object_key
    content = await file.read(MAX_PHOTO_BYTES + 1)
    if len(content) > MAX_PHOTO_BYTES:
        raise ValueError("La imagen supera el limite de 10 MB")
    destination.write_bytes(content)
    return object_key, f"/media/{object_key}"