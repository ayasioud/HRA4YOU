from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_username: str
    app_password: str
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60


    crowd_base_url: str = ""
    crowd_app_name: str = ""
    crowd_app_password: str = ""
    crowd_callback_url: str = "http://localhost:8000/auth/crowd/callback"
    frontend_url: str = "http://localhost:4200"


    terraform_dir: str
    terraform_var_file: str = "app.auto.tfvars.json"
    terraform_enabled: bool = False
    target_vpc_name: str
    apache_private_ip: str
    apache_sg_name: str
    apache_instance_id: str
    vpc_cidr: str
    aws_region: str = "eu-west-3"
    aws_profile: str | None = None
    ssh_port_counter_table: str = "hra4you-port-counter"
    oracle_user: str | None = None
    oracle_password: str | None = None
    oracle_host: str | None = None
    oracle_port: int = 1521
    oracle_service_name: str | None = None
    cors_allow_origins: str = "http://localhost:4200,http://127.0.0.1:4200"
    cors_allow_credentials: bool = True
    cors_allow_methods: str = "GET,POST,PUT,PATCH,DELETE,OPTIONS"
    cors_allow_headers: str = "Authorization,Content-Type"
    apache_sg_id: str = "sg-0b148afdb0ae402b8"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
    )

    def get_cors_allow_origins(self) -> list[str]:
        return [item.strip() for item in self.cors_allow_origins.split(",") if item.strip()]

    def get_cors_allow_methods(self) -> list[str]:
        return [item.strip() for item in self.cors_allow_methods.split(",") if item.strip()]

    def get_cors_allow_headers(self) -> list[str]:
        return [item.strip() for item in self.cors_allow_headers.split(",") if item.strip()]


settings = Settings()