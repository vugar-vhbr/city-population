"""
Pydantic models for request/response validation and serialization
Provides automatic validation, type checking, and API documentation
"""

from pydantic import BaseModel, Field, validator
from typing import Optional


class CityPopulation(BaseModel):
    """
    Model for city population upsert requests
    Validates incoming data and ensures type safety
    """
    city: str = Field(
        ...,  # Required field
        min_length=1,
        max_length=100,
        description="Name of the city",
        example="New York"
    )
    population: int = Field(
        ...,  # Required field
        ge=0,  # Greater than or equal to 0
        description="Population count (must be non-negative)",
        example=8336817
    )

    @validator('city')
    def validate_city_name(cls, v):
        """
        Custom validator to ensure city name is not empty after stripping whitespace
        """
        if not v.strip():
            raise ValueError("City name cannot be empty or whitespace only")
        return v.strip()

    class Config:
        # Enable JSON schema generation for OpenAPI docs
        schema_extra = {
            "example": {
                "city": "Tokyo",
                "population": 13960000
            }
        }


class CityQuery(BaseModel):
    """
    Model for city query responses
    """
    city: str = Field(description="Name of the city")
    population: int = Field(description="Population count")

    class Config:
        schema_extra = {
            "example": {
                "city": "london",
                "population": 9002488
            }
        }


class HealthResponse(BaseModel):
    """
    Model for health check endpoint response
    Used by Kubernetes probes to determine service health
    """
    status: str = Field(
        description="Overall application status",
        example="OK"
    )
    database: str = Field(
        description="Database connection status",
        example="connected"
    )
