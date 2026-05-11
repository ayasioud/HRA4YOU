from pydantic import BaseModel, Field


class EC2CreateRequest(BaseModel):
    instance_name: str = Field(..., min_length=3)
    image_id: str
    instance_type: str
    storage_size: int = Field(..., gt=0)
    created_by: str
    owner_agency: str


class EC2CreateResponse(BaseModel):
    status: str
    message: str
    instance_name: str
    terraform_enabled: bool
    stdout: str | None = None
    stderr: str | None = None


class EC2InstanceSshPortResponse(BaseModel):
    instance_name: str
    ssh_port: int
    ssh_command: str
