import boto3

from ..core.config import settings


def get_boto3_session():
    if settings.aws_profile:
        return boto3.Session(
            profile_name=settings.aws_profile,
            region_name=settings.aws_region,
        )

    return boto3.Session(region_name=settings.aws_region)


def get_available_images() -> list[dict]:
    session = get_boto3_session()
    ec2 = session.client("ec2")

    owned_response = ec2.describe_images(
        Owners=["self"],
        Filters=[
            {"Name": "state", "Values": ["available"]},
        ],
    )

    executable_response = ec2.describe_images(
        ExecutableUsers=["self"],
        Filters=[
            {"Name": "state", "Values": ["available"]},
        ],
    )

    all_images = owned_response.get("Images", []) + executable_response.get("Images", [])

    unique_images = {}
    for image in all_images:
        unique_images[image["ImageId"]] = image

    images = sorted(
        unique_images.values(),
        key=lambda image: image.get("CreationDate", ""),
        reverse=True,
    )

    return [
        {
            "image_id": image["ImageId"],
            "name": image.get("Name", "Sans nom"),
            "description": image.get("Description", ""),
            "creation_date": image.get("CreationDate", ""),
        }
        for image in images[:50]
    ]
def get_image_by_id(image_id: str) -> list[dict]:
    session = get_boto3_session()
    ec2 = session.client("ec2")

    response = ec2.describe_images(
        ImageIds=[image_id]
    )

    return response.get("Images", [])
