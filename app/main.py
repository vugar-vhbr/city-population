"""
Main FastAPI application for City Population Management API
Provides REST endpoints for health checks, upserting, and querying city populations
"""

from fastapi import FastAPI, HTTPException, status
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from typing import Dict, Any

from app.models import CityPopulation, CityQuery, HealthResponse
from app.database import ElasticsearchClient
from app.config import settings

# Configure structured logging for production observability
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global Elasticsearch client instance
es_client = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context manager for startup and shutdown events
    - Initializes Elasticsearch connection on startup
    - Gracefully closes connections on shutdown
    """
    global es_client

    # Startup: Initialize database connection
    logger.info("Starting application...")
    es_client = ElasticsearchClient(
        hosts=settings.ELASTICSEARCH_HOST,
        index_name=settings.ELASTICSEARCH_INDEX
    )
    await es_client.connect()
    logger.info("Elasticsearch connection established")

    yield  # Application runs here

    # Shutdown: Clean up resources
    logger.info("Shutting down application...")
    await es_client.close()
    logger.info("Elasticsearch connection closed")


# Initialize FastAPI application with metadata for API documentation
app = FastAPI(
    title="City Population API",
    description="RESTful API for managing city population data",
    version="1.0.0",
    lifespan=lifespan
)


@app.get("/health", response_model=HealthResponse, status_code=status.HTTP_200_OK)
async def health_check() -> Dict[str, Any]:
    """
    Health check endpoint for Kubernetes liveness and readiness probes

    Returns:
        - status: Application health status
        - database: Elasticsearch connection status

    Raises:
        - 503 Service Unavailable if Elasticsearch is unreachable
    """
    try:
        # Verify Elasticsearch cluster health
        db_status = await es_client.health_check()

        if not db_status:
            # Database unhealthy - return 503 to fail health probes
            logger.error("Elasticsearch health check failed")
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={
                    "status": "unhealthy",
                    "database": "disconnected"
                }
            )

        # All systems operational
        logger.debug("Health check passed")
        return {
            "status": "OK",
            "database": "connected"
        }

    except Exception as e:
        logger.error(f"Health check error: {str(e)}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "unhealthy",
                "database": "error",
                "error": str(e)
            }
        )


@app.post("/city", status_code=status.HTTP_200_OK)
async def upsert_city(city_data: CityPopulation) -> Dict[str, Any]:
    """
    Upsert endpoint: Insert or update city population data

    Args:
        city_data: CityPopulation model containing city name and population

    Returns:
        - message: Success message
        - city: City name that was upserted
        - population: Population value that was set
        - operation: Whether it was an 'insert' or 'update'

    Raises:
        - 400 Bad Request if validation fails
        - 500 Internal Server Error if database operation fails
    """
    try:
        # Normalize city name to lowercase for consistent querying
        city_name = city_data.city.lower().strip()
        population = city_data.population

        # Validate population is non-negative
        if population < 0:
            logger.warning(f"Invalid population value: {population}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Population must be a non-negative integer"
            )

        # Check if city already exists to determine operation type
        existing = await es_client.get_city(city_name)
        operation = "update" if existing else "insert"

        # Perform upsert operation in Elasticsearch
        await es_client.upsert_city(city_name, population)

        logger.info(f"Successfully {operation}ed city: {city_name} with population: {population}")

        return {
            "message": f"City {operation}ed successfully",
            "city": city_name,
            "population": population,
            "operation": operation
        }

    except HTTPException:
        # Re-raise HTTP exceptions (validation errors)
        raise
    except Exception as e:
        # Log and return 500 for unexpected errors
        logger.error(f"Error upserting city {city_data.city}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upsert city: {str(e)}"
        )


@app.get("/city/{city_name}", status_code=status.HTTP_200_OK)
async def get_city_population(city_name: str) -> Dict[str, Any]:
    """
    Query endpoint: Retrieve population for a specified city

    Args:
        city_name: Name of the city (case-insensitive)

    Returns:
        - city: City name
        - population: Current population count

    Raises:
        - 404 Not Found if city doesn't exist
        - 500 Internal Server Error if database query fails
    """
    try:
        # Normalize city name for consistent lookups
        city_name = city_name.lower().strip()

        # Query Elasticsearch for city data
        result = await es_client.get_city(city_name)

        if result is None:
            # City not found in database
            logger.warning(f"City not found: {city_name}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"City '{city_name}' not found"
            )

        logger.info(f"Retrieved population for city: {city_name}")

        return {
            "city": city_name,
            "population": result
        }

    except HTTPException:
        # Re-raise HTTP exceptions (not found errors)
        raise
    except Exception as e:
        # Log and return 500 for unexpected errors
        logger.error(f"Error querying city {city_name}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to query city: {str(e)}"
        )


# Optional: List all cities endpoint (useful for debugging)
@app.get("/cities", status_code=status.HTTP_200_OK)
async def list_all_cities() -> Dict[str, Any]:
    """
    Bonus endpoint: List all cities and their populations
    Useful for debugging and data verification

    Returns:
        - count: Total number of cities
        - cities: List of all city-population pairs
    """
    try:
        cities = await es_client.list_all_cities()

        return {
            "count": len(cities),
            "cities": cities
        }

    except Exception as e:
        logger.error(f"Error listing cities: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list cities: {str(e)}"
        )
