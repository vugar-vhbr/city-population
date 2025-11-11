"""
Elasticsearch database client with async operations
Handles all database interactions with proper error handling and connection management
"""

from elasticsearch import AsyncElasticsearch
from typing import Optional, List, Dict, Any
import logging

logger = logging.getLogger(__name__)


class ElasticsearchClient:
    """
    Async Elasticsearch client for city population data management
    Implements connection pooling and automatic reconnection
    """

    def __init__(self, hosts: str, index_name: str):
        """
        Initialize Elasticsearch client configuration

        Args:
            hosts: Elasticsearch host URL (e.g., 'http://elasticsearch:9200')
            index_name: Name of the index to store city data
        """
        self.hosts = hosts
        self.index_name = index_name
        self.client: Optional[AsyncElasticsearch] = None

    async def connect(self):
        """
        Establish connection to Elasticsearch cluster
        Creates index if it doesn't exist with proper mappings
        """
        try:
            # Initialize async Elasticsearch client with connection pooling
            self.client = AsyncElasticsearch(
                hosts=[self.hosts],
                request_timeout=30,
                max_retries=3,
                retry_on_timeout=True
            )

            # Wait for cluster to be ready
            await self.client.cluster.health(wait_for_status='yellow')

            # Create index with mappings if it doesn't exist
            if not await self.client.indices.exists(index=self.index_name):
                await self.client.indices.create(
                    index=self.index_name,
                    body={
                        "mappings": {
                            "properties": {
                                "city": {
                                    "type": "keyword"  # Exact match for city names
                                },
                                "population": {
                                    "type": "long"  # Integer type for population
                                }
                            }
                        },
                        "settings": {
                            "number_of_shards": 1,  # Single shard for small dataset
                            "number_of_replicas": 1  # One replica for HA
                        }
                    }
                )
                logger.info(f"Created index: {self.index_name}")

            logger.info(f"Connected to Elasticsearch at {self.hosts}")

        except Exception as e:
            logger.error(f"Failed to connect to Elasticsearch: {str(e)}")
            raise

    async def close(self):
        """
        Gracefully close Elasticsearch connection
        Should be called during application shutdown
        """
        if self.client:
            await self.client.close()
            logger.info("Elasticsearch connection closed")

    async def health_check(self) -> bool:
        """
        Check Elasticsearch cluster health
        Used by health endpoint to verify database connectivity

        Returns:
            True if cluster is healthy (green or yellow), False otherwise
        """
        try:
            health = await self.client.cluster.health()
            status = health['status']
            # Yellow is acceptable (means replicas not fully allocated)
            return status in ['green', 'yellow']
        except Exception as e:
            logger.error(f"Elasticsearch health check failed: {str(e)}")
            return False

    async def upsert_city(self, city: str, population: int) -> bool:
        """
        Insert or update city population data
        Uses city name as document ID for automatic upsert behavior

        Args:
            city: City name (normalized to lowercase)
            population: Population count

        Returns:
            True if operation successful
        """
        try:
            # Use city name as document ID for idempotent upserts
            await self.client.index(
                index=self.index_name,
                id=city,  # Document ID = city name (ensures upsert)
                body={
                    "city": city,
                    "population": population
                },
                refresh=True  # Make immediately searchable (use 'wait_for' in prod)
            )
            logger.debug(f"Upserted city: {city} with population: {population}")
            return True

        except Exception as e:
            logger.error(f"Failed to upsert city {city}: {str(e)}")
            raise

    async def get_city(self, city: str) -> Optional[int]:
        """
        Retrieve population for a specific city

        Args:
            city: City name (normalized to lowercase)

        Returns:
            Population count if city exists, None otherwise
        """
        try:
            # Retrieve document by ID (city name)
            response = await self.client.get(
                index=self.index_name,
                id=city,
                _source=['population']  # Only fetch population field
            )

            return response['_source']['population']

        except Exception as e:
            # Document not found or other error
            error_str = str(e).lower()
            if 'not_found' in error_str or 'notfounderror' in error_str or "'found': false" in error_str:
                logger.debug(f"City not found: {city}")
                return None
            else:
                logger.error(f"Error retrieving city {city}: {str(e)}")
                raise

    async def list_all_cities(self) -> List[Dict[str, Any]]:
        """
        Retrieve all cities and their populations
        Useful for debugging and verification

        Returns:
            List of dictionaries containing city and population data
        """
        try:
            # Search for all documents (use pagination for large datasets in production)
            response = await self.client.search(
                index=self.index_name,
                body={
                    "query": {"match_all": {}},
                    "size": 10000,  # Max results (use scroll API for larger datasets)
                    "sort": [{"city": "asc"}]  # Sort alphabetically
                }
            )

            # Extract city data from search results
            cities = [
                {
                    "city": hit['_source']['city'],
                    "population": hit['_source']['population']
                }
                for hit in response['hits']['hits']
            ]

            return cities

        except Exception as e:
            logger.error(f"Error listing cities: {str(e)}")
            raise
