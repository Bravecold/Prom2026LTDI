from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: EmailStr


class PendingUserRead(UserRead):
    created_at: datetime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class StudentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    classroom: str
    photo_url: str | None


class PhotoRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    student_id: int | None
    url: str
    caption: str | None
    created_at: datetime


class CommentCreate(BaseModel):
    body: str = Field(min_length=1, max_length=280)


class CommentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    photo_id: int
    body: str
    created_at: datetime
    author: UserRead