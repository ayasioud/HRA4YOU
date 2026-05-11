from sqlalchemy import Boolean, DateTime, Identity, Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime



from .core.database import Base


class InstanceType(Base):
    __tablename__ = "INSTANCE_TYPES"

    id: Mapped[int] = mapped_column(
        Integer,
        Identity(start=1),
        primary_key=True,
    )
    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

class AppUser(Base):
        __tablename__ = "APP_USERS"

        id: Mapped[int] = mapped_column(
            Integer,
            Identity(start=1),
            primary_key=True,
        )
        username: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
        email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
        password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
        role: Mapped[str] = mapped_column(String(50), default="admin", nullable=False)
        is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
        created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

