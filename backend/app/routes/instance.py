from fastapi import APIRouter, Depends, HTTPException, Query
from ..core.security import get_current_user, require_admin
from ..schemas.instance import EC2CreateRequest, EC2CreateResponse, EC2InstanceSshPortResponse
from ..services.terraform_service import run_terraform_apply, get_instance_ssh_port
from ..services.aws_images_service import get_available_images, get_image_by_id
from ..services.destroy_service import destroy_instance

router = APIRouter(prefix="/ec2", tags=["ec2"])



@router.post("/create", response_model=EC2CreateResponse)
def create_ec2(
    payload: EC2CreateRequest,
    current_user: dict = Depends(require_admin),  # ← CHANGÉ
) -> EC2CreateResponse:
    result = run_terraform_apply(payload)
    return EC2CreateResponse(**result)



@router.get("/{instance_name}/ssh-port", response_model=EC2InstanceSshPortResponse)
def get_ec2_ssh_port(
    instance_name: str,
    current_user: dict = Depends(get_current_user),
) -> EC2InstanceSshPortResponse:
    try:
        result = get_instance_ssh_port(instance_name)
        return EC2InstanceSshPortResponse(**result)
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la lecture du port SSH: {error}") from error


@router.get("/images")
def list_ec2_images(current_user: dict = Depends(get_current_user)):
    return get_available_images()

@router.get("/image-by-id")
def get_ec2_image_by_id(
    image_id: str = Query(...),
    current_user: dict = Depends(get_current_user),
):
    return get_image_by_id(image_id)
@router.delete("/{instance_name}")
def delete_ec2(
    instance_name: str,
    current_user: dict = Depends(require_admin),
):

    result = destroy_instance(instance_name)
    return result