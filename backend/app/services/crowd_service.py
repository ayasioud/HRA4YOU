import httpx
from fastapi import HTTPException, status
from ..core.config import settings


def _crowd_auth() -> tuple[str, str]:
    return (settings.crowd_app_name, settings.crowd_app_password)


def _crowd_headers() -> dict:
    return {
        "Accept": "application/json",
        "Content-Type": "application/json",
    }


def get_crowd_sso_url() -> str:
    return (
        f"{settings.crowd_base_url}/crowd/console/login.action"
        f"?originalUrl={settings.crowd_callback_url}"
    )


def validate_crowd_token(token: str) -> dict:
    url = f"{settings.crowd_base_url}/crowd/rest/usermanagement/1/session/{token}"
    try:
        response = httpx.get(
            url,
            auth=_crowd_auth(),
            headers=_crowd_headers(),
            timeout=10.0,
        )
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Impossible de contacter Crowd : {exc}",
        ) from exc

    if response.status_code == 404:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token SSO Crowd invalide ou expiré",
        )
    if response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Erreur Crowd : {response.status_code}",
        )

    data = response.json()
    user = data.get("user", {})
    return {
        "username": user.get("name", ""),
        "display_name": user.get("display-name", user.get("name", "")),
        "email": user.get("email", ""),
    }


def get_user_groups(username: str) -> list[str]:
    url = (
        f"{settings.crowd_base_url}/crowd/rest/usermanagement/1"
        f"/user/group/direct?username={username}"
    )
    print(f"URL groupes : {url}")  # ← AJOUTE

    try:
        response = httpx.get(
            url,
            auth=_crowd_auth(),
            headers=_crowd_headers(),
            timeout=10.0,
        )
        print(f"Status groupes : {response.status_code}")  # ← AJOUTE
        print(f"Response groupes : {response.text}")  # ← AJOUTE
    except httpx.RequestError:
        return []

    if response.status_code != 200:
        return []

    data = response.json()
    groups = data.get("groups", [])
    return [g.get("name", "") for g in groups]

def determine_role(groups: list[str]) -> str:
    print(f"Groupes reçus de Crowd : {groups}")  # ← AJOUTE
    group_names_lower = [g.lower() for g in groups]
    print(f"Groupes en minuscule : {group_names_lower}")  # ← AJOUTE
    if any("admin" in g for g in group_names_lower):
        return "admin"
    return "user"

def authenticate_with_crowd(username: str, password: str) -> dict:
    url = f"{settings.crowd_base_url}/crowd/rest/usermanagement/1/authentication?username={username}"

    try:
        response = httpx.post(
            url,
            auth=_crowd_auth(),
            headers=_crowd_headers(),
            json={"value": password},
            timeout=10.0,
        )
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Impossible de contacter Crowd : {exc}",
        ) from exc

    if response.status_code in [400, 401]:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Username ou mot de passe incorrect",
        )

    # Crowd retourne body vide ou JSON selon la version
    try:
        data = response.json()
    except Exception:
        data = {}

    return {
        "username": data.get("name", username),
        "display_name": data.get("display-name", username),
        "email": data.get("email", ""),
    }