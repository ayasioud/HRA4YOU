from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routes.instance import router as ec2_router
from .core.database import Base, SessionLocal, engine
from .core.config import settings
from . import models
from .models import AppUser
from .routes.instance_type import router as instance_type_router
from .routes import user
from .services.password_service import hash_password
from .routes.auth import router as auth_router


from .routes.auth import router as auth_router

app = FastAPI(title="HRA4YOU API", version="1.0.0")


def seed_default_admin_user() -> None:
    db = SessionLocal()
    try:
        existing_user = db.query(AppUser).first()
        if existing_user:
            return

        admin_user = AppUser(
            username=settings.app_username,
            email=None,
            password_hash=hash_password(settings.app_password),
            role="admin",
            is_active=True,
        )

        db.add(admin_user)
        db.commit()
    finally:
        db.close()


@app.on_event("startup")
def on_startup() -> None:
    try:
        Base.metadata.create_all(bind=engine)
        seed_default_admin_user()
    except Exception as e:
        print(f"Oracle non disponible au démarrage : {e}")
        print(" Le backend démarre sans Oracle — certaines fonctionnalités seront indisponibles")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.get_cors_allow_origins(),
    allow_credentials=settings.cors_allow_credentials,
    allow_methods=settings.get_cors_allow_methods(),
    allow_headers=settings.get_cors_allow_headers(),
)


@app.get("/")
def read_root():
    return {"message": "Backend OK"}


@app.get("/health")
def health():
    return {"status": "healthy"}


app.include_router(auth_router)
app.include_router(ec2_router)
app.include_router(instance_type_router)
app.include_router(user.router)


