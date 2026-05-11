from pydantic import BaseModel


class InstanceTypeBase(BaseModel):
    name: str
    description: str | None = None
    is_active: bool = True


class InstanceTypeCreate(InstanceTypeBase):
    pass


class InstanceTypeUpdate(BaseModel):
    name: str
    description: str | None = None
    is_active: bool = True


class InstanceTypeResponse(InstanceTypeBase):
    id: int

    class Config:
        from_attributes = True


class InstanceTypeStatusUpdate(BaseModel):
    is_active: bool
