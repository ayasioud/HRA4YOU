from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from .config import settings


def build_oracle_url() -> str:
    return (
        f"oracle+oracledb://{settings.oracle_user}:{settings.oracle_password}"
        f"@{settings.oracle_host}:{settings.oracle_port}/?service_name={settings.oracle_service_name}"
    )


DATABASE_URL = build_oracle_url()

engine = create_engine(DATABASE_URL, echo=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
