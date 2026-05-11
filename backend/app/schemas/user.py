from datetime import datetime

from pydantic import BaseModel, EmailStr


class UserCreate(BaseModel):
    username: str
    email: EmailStr | None = None
    password: str
    role: str = "admin"
    is_active: bool = True


class UserResponse(BaseModel):
    id: int
    username: str
    email: EmailStr | None = None
    role: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
