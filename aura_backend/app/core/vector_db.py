import os
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams
from aura_backend.app.core.config import settings

# Initialize Qdrant client in memory (or local directory for persistence)
# We use local files for persistence so user uploads are not lost on restart
PERSIST_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 
    "data", 
    "qdrant"
)
os.makedirs(PERSIST_DIR, exist_ok=True)

# Use persistence path for local vector database with in-memory fallback on lock errors
try:
    qdrant_client = QdrantClient(path=PERSIST_DIR)
except Exception as e:
    print(f"Warning: Could not initialize local Qdrant database: {e}. Falling back to in-memory client.")
    qdrant_client = QdrantClient(location=":memory:")

COLLECTION_NAME = "aura_knowledge"

def init_vector_db():
    """Initializes the Qdrant collection if it does not exist."""
    global qdrant_client
    try:
        # Check if collection exists
        collections = qdrant_client.get_collections().collections
        exists = any(c.name == COLLECTION_NAME for c in collections)
        
        if not exists:
            qdrant_client.create_collection(
                collection_name=COLLECTION_NAME,
                vectors_config=VectorParams(
                    size=768,  # Gemini text-embedding-004 output dimension is 768
                    distance=Distance.COSINE
                )
            )
            print(f"Created Qdrant collection: {COLLECTION_NAME}")
        else:
            print(f"Qdrant collection: {COLLECTION_NAME} already exists")
    except Exception as e:
        print(f"Error initializing vector database: {e}")
        # Fallback to in-memory if disk database fails
        qdrant_client = QdrantClient(location=":memory:")
        qdrant_client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=768, distance=Distance.COSINE)
        )
