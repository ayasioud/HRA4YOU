from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from ..core.database import get_db
from ..core.security import create_access_token
from ..core.config import settings
from ..models import AppUser
from ..services.crowd_service import (
    get_crowd_sso_url,
    validate_crowd_token,
    get_user_groups,
    determine_role,
)
from ..services.crowd_service import (
    get_crowd_sso_url,
    validate_crowd_token,
    get_user_groups,
    determine_role,
    authenticate_with_crowd,
)
from ..schemas.auth import LoginRequest, TokenResponse
from fastapi import APIRouter, Depends, HTTPException, status, Request, Cookie
from fastapi.responses import RedirectResponse
from typing import Optional
router = APIRouter(prefix="/auth", tags=["auth"])


# ── Login classique (conservé pour admin) ──────────────────────
@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest):
    """Login via Crowd — credentials vérifiés par Crowd en arrière-plan."""

    # Vérification via Crowd
    user_info = authenticate_with_crowd(payload.username, payload.password)
    username = user_info["username"]

    # Récupérer les groupes pour le rôle
    groups = get_user_groups(username)
    role = determine_role(groups)

    # Créer le JWT
    access_token = create_access_token(
        data={
            "sub": username,
            "role": role,
            "display_name": user_info.get("display_name", username),
            "email": user_info.get("email", ""),
            "auth_method": "crowd",
        }
    )
    return TokenResponse(access_token=access_token)

# ── SSO Crowd (NOUVEAU) ────────────────────────────────────────
@router.get("/crowd/login")
def crowd_login():
    sso_url = get_crowd_sso_url()
    return RedirectResponse(url=sso_url, status_code=302)


@router.get("/crowd/callback")
def crowd_callback(token: str | None = None):
    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token SSO Crowd manquant",
        )

    user_info = validate_crowd_token(token)
    username = user_info["username"]
    groups = get_user_groups(username)
    role = determine_role(groups)

    access_token = create_access_token(
        data={
            "sub": username,
            "role": role,
            "display_name": user_info.get("display_name", username),
            "email": user_info.get("email", ""),
            "auth_method": "crowd_sso",
        }
    )

    redirect_url = f"{settings.frontend_url}/auth/callback#token={access_token}"
    return RedirectResponse(url=redirect_url, status_code=302)


from fastapi import APIRouter, Depends, HTTPException, status, Request, Cookie
from fastapi.responses import RedirectResponse
from typing import Optional

@router.get("/crowd/callback")
def crowd_callback(
    request: Request,
    crowd_token_key: Optional[str] = Cookie(None, alias="crowd.token_key")
):
    # Lire le token depuis le cookie Crowd
    token = crowd_token_key or request.query_params.get("token")

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token Crowd manquant",
        )

    user_info = validate_crowd_token(token)
    username = user_info["username"]
    groups = get_user_groups(username)
    role = determine_role(groups)

    access_token = create_access_token(
        data={
            "sub": username,
            "role": role,
            "display_name": user_info.get("display_name", username),
            "email": user_info.get("email", ""),
            "auth_method": "crowd_sso",
        }
    )

    redirect_url = f"{settings.frontend_url}/auth/callback#token={access_token}"
    return RedirectResponse(url=redirect_url, status_code=302)