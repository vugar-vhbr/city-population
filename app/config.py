"""
Application configuration using environment variables
Follows 12-factor app methodology for cloud-native deployments
"""

from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables
    Provides type validation and default values
    """

    # Application settings
    APP_NAME: str = "city-population-api"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Server configuration
    HOST: str = "0.0.0.0"  # Listen on all interfaces
    PORT: int = 8000

    # Elasticsearch configuration
    ELASTICSEARCH_HOST: str = "http://elasticsearch:9200"  # K8s service name
    ELASTICSEARCH_INDEX: str = "cities"

    # Optional: Authentication (for production)
    ELASTICSEARCH_USER: Optional[str] = None
    ELASTICSEARCH_PASSWORD: Optional[str] = None

    class Config:
        # Load from .env file if present (for local development)
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


# Global settings instance
settings = Settings()
