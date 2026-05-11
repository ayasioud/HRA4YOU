from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..core.database import get_db
from ..core.security import require_admin
from ..models import AppUser
from ..services.password_service import hash_password
from ..schemas.user import UserCreate, UserResponse

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/", response_model=list[UserResponse])
def list_users(
    current_user: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return db.query(AppUser).order_by(AppUser.id.asc()).all()


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    payload: UserCreate,
    current_user: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    existing_username = db.query(AppUser).filter(AppUser.username == payload.username).first()
    if existing_username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ce username existe deja",
        )

    if payload.email:
        existing_email = db.query(AppUser).filter(AppUser.email == payload.email).first()
        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cet email existe deja",
            )

    user = AppUser(
        username=payload.username,
        email=payload.email,
        password_hash=hash_password(payload.password),
        role=payload.role,
        is_active=payload.is_active,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user
