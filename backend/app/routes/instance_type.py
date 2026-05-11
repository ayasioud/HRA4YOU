from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..core.database import get_db
from ..models import InstanceType
from ..schemas.instance_type import InstanceTypeResponse, InstanceTypeCreate, InstanceTypeStatusUpdate
from ..core.security import require_admin




router = APIRouter(prefix="/instance-types", tags=["instance-types"])


@router.get("/", response_model=list[InstanceTypeResponse])
def list_instance_types(
    current_user: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return db.query(InstanceType).order_by(InstanceType.id.asc()).all()

@router.post("/", response_model=InstanceTypeResponse, status_code=status.HTTP_201_CREATED)
def create_instance_type(
    payload: InstanceTypeCreate,
    current_user: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    existing = db.query(InstanceType).filter(InstanceType.name == payload.name).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ce type d'instance existe deja",
        )

    instance_type = InstanceType(
        name=payload.name,
        description=payload.description,
        is_active=payload.is_active,
    )

    db.add(instance_type)
    db.commit()
    db.refresh(instance_type)

    return instance_type
@router.delete("/{instance_type_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_instance_type(
    instance_type_id: int,
    current_user: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    instance_type = db.query(InstanceType).filter(InstanceType.id == instance_type_id).first()

    if not instance_type:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Type d'instance introuvable",
        )

    db.delete(instance_type)
    db.commit()
@router.patch("/{instance_type_id}/status", response_model=InstanceTypeResponse)
def update_instance_type_status(
    instance_type_id: int,
    payload: InstanceTypeStatusUpdate,
    current_user: dict = Depends(require_admin),
    db: Session = Depends(get_db),
):
    instance_type = db.query(InstanceType).filter(InstanceType.id == instance_type_id).first()

    if not instance_type:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Type d'instance introuvable",
        )

    instance_type.is_active = payload.is_active

    db.commit()
    db.refresh(instance_type)

    return instance_type

