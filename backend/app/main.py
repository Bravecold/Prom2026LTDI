from pathlib import Path

from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from .auth import create_access_token, get_current_user, hash_password, verify_password
from .config import get_settings
from .db import Base, engine, get_db
from .models import Comment, Photo, Student, User
from .schemas import CommentCreate, CommentRead, PhotoRead, StudentRead, Token, UserCreate, UserRead
from .storage import save_photo

settings = get_settings()
app = FastAPI(title=settings.app_name, version="0.1.0")
app.add_middleware(CORSMiddleware, allow_origins=settings.allowed_origins, allow_credentials=True, allow_methods=["*"], allow_headers=["*"])


@app.on_event("startup")
def create_tables() -> None:
    Base.metadata.create_all(bind=engine)


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/auth/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def register(payload: UserCreate, database: Session = Depends(get_db)) -> User:
    email = payload.email.lower()
    if database.scalar(select(User).where(User.email == email)):
        raise HTTPException(status_code=409, detail="El correo ya esta registrado")
    user = User(name=payload.name.strip(), email=email, password_hash=hash_password(payload.password))
    database.add(user)
    database.commit()
    database.refresh(user)
    return user


@app.post("/api/auth/login", response_model=Token)
def login(form: OAuth2PasswordRequestForm = Depends(), database: Session = Depends(get_db)) -> Token:
    user = database.scalar(select(User).where(User.email == form.username.lower()))
    if user is None or not verify_password(form.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Correo o contrasena incorrectos", headers={"WWW-Authenticate": "Bearer"})
    return Token(access_token=create_access_token(user.id))


@app.get("/api/auth/me", response_model=UserRead)
def me(user: User = Depends(get_current_user)) -> User:
    return user


@app.get("/api/students", response_model=list[StudentRead])
def list_students(classroom: str | None = None, database: Session = Depends(get_db)) -> list[Student]:
    statement = select(Student).order_by(Student.classroom, Student.name)
    if classroom:
        statement = statement.where(Student.classroom == classroom.upper())
    return list(database.scalars(statement).all())


@app.post("/api/photos", response_model=PhotoRead, status_code=status.HTTP_201_CREATED)
async def upload_photo(student_id: int | None = Form(default=None), caption: str | None = Form(default=None), file: UploadFile = File(...), user: User = Depends(get_current_user), database: Session = Depends(get_db)) -> Photo:
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=415, detail="Solo se permiten imagenes")
    if caption and len(caption) > 280:
        raise HTTPException(status_code=422, detail="El texto no puede superar 280 caracteres")
    if student_id and database.get(Student, student_id) is None:
        raise HTTPException(status_code=404, detail="Estudiante no encontrado")
    try:
        object_key, url = await save_photo(file)
    except ValueError as error:
        raise HTTPException(status_code=413, detail=str(error)) from error
    photo = Photo(student_id=student_id, uploaded_by=user.id, object_key=object_key, url=url, caption=caption, approved=False)
    database.add(photo)
    database.commit()
    database.refresh(photo)
    return photo


@app.get("/api/photos/{photo_id}/comments", response_model=list[CommentRead])
def list_comments(photo_id: int, database: Session = Depends(get_db)) -> list[Comment]:
    statement = select(Comment).options(joinedload(Comment.author)).where(Comment.photo_id == photo_id, Comment.approved.is_(True)).order_by(Comment.created_at)
    return list(database.scalars(statement).unique().all())


@app.post("/api/photos/{photo_id}/comments", response_model=CommentRead, status_code=status.HTTP_201_CREATED)
def create_comment(photo_id: int, payload: CommentCreate, user: User = Depends(get_current_user), database: Session = Depends(get_db)) -> Comment:
    if database.get(Photo, photo_id) is None:
        raise HTTPException(status_code=404, detail="Foto no encontrada")
    comment = Comment(photo_id=photo_id, author_id=user.id, body=payload.body.strip(), approved=False)
    database.add(comment)
    database.commit()
    database.refresh(comment)
    comment.author = user
    return comment


@app.get("/media/{filename}")
def local_media(filename: str) -> FileResponse:
    media_directory = Path(settings.storage_directory).resolve()
    path = (media_directory / filename).resolve()
    if media_directory not in path.parents or not path.is_file():
        raise HTTPException(status_code=404, detail="Archivo no encontrado")
    return FileResponse(path)