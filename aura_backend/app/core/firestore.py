import os
import json
import pymongo
from typing import Dict, Any, List, Optional

# Read environment variables
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DATABASE_NAME = os.getenv("MONGO_DB", "aura")

class MongoDocumentSnapshot:
    def __init__(self, doc_id: str, data: Optional[Dict[str, Any]]):
        self.id = doc_id
        self._data = data
        self.exists = data is not None

    def to_dict(self) -> Optional[Dict[str, Any]]:
        return self._data

class MongoQuery:
    def __init__(self, collection, filters: Dict[str, Any]):
        self.collection = collection
        self.filters = filters

    def where(self, field: str, op: str, value: Any):
        new_filters = dict(self.filters)
        if op == "==":
            if isinstance(value, (int, float)):
                new_filters[field] = {"$in": [value, str(value)]}
            elif isinstance(value, str):
                if value.isdigit():
                    new_filters[field] = {"$in": [value, int(value)]}
                else:
                    new_filters[field] = value
            else:
                new_filters[field] = value
        elif op == "<":
            new_filters[field] = {"$lt": value}
        elif op == ">":
            new_filters[field] = {"$gt": value}
        return MongoQuery(self.collection, new_filters)

    def get(self) -> List[MongoDocumentSnapshot]:
        results = []
        cursor = self.collection.find(self.filters)
        for doc in cursor:
            doc_id = str(doc.get("_id", ""))
            doc_data = dict(doc)
            if "_id" in doc_data:
                del doc_data["_id"]
            results.append(MongoDocumentSnapshot(doc_id, doc_data))
        return results

class MongoDocument:
    def __init__(self, collection, doc_id: str):
        self.collection = collection
        self.doc_id = str(doc_id)

    def get(self) -> MongoDocumentSnapshot:
        key_id = self.doc_id
        if self.doc_id.isdigit():
            try:
                key_id = int(self.doc_id)
            except ValueError:
                pass
                
        doc = self.collection.find_one({"_id": {"$in": [self.doc_id, key_id]}})
        if doc is None:
            return MongoDocumentSnapshot(self.doc_id, None)
            
        doc_data = dict(doc)
        if "_id" in doc_data:
            del doc_data["_id"]
        return MongoDocumentSnapshot(self.doc_id, doc_data)

    def set(self, data: Dict[str, Any], merge: bool = False):
        key_id = self.doc_id
        if self.doc_id.isdigit():
            try:
                key_id = int(self.doc_id)
            except ValueError:
                pass

        serializable_data = json.loads(json.dumps(data, default=str))

        if merge:
            self.collection.update_one({"_id": key_id}, {"$set": serializable_data}, upsert=True)
        else:
            data_to_save = dict(serializable_data)
            data_to_save["_id"] = key_id
            self.collection.replace_one({"_id": key_id}, data_to_save, upsert=True)

    def update(self, data: Dict[str, Any]):
        self.set(data, merge=True)

    def delete(self):
        key_id = self.doc_id
        if self.doc_id.isdigit():
            try:
                key_id = int(self.doc_id)
            except ValueError:
                pass
        self.collection.delete_one({"_id": key_id})

class MongoCollection:
    def __init__(self, db_mongo, name: str):
        self.db_mongo = db_mongo
        self.name = name
        self.collection = db_mongo[name]

    def document(self, doc_id: str):
        return MongoDocument(self.collection, doc_id)

    def where(self, field: str, op: str, value: Any):
        filters = {}
        if op == "==":
            if isinstance(value, (int, float)):
                filters[field] = {"$in": [value, str(value)]}
            elif isinstance(value, str):
                if value.isdigit():
                    filters[field] = {"$in": [value, int(value)]}
                else:
                    filters[field] = value
            else:
                filters[field] = value
        elif op == "<":
            filters[field] = {"$lt": value}
        elif op == ">":
            filters[field] = {"$gt": value}
        return MongoQuery(self.collection, filters)

    def get(self) -> List[MongoDocumentSnapshot]:
        results = []
        cursor = self.collection.find({})
        for doc in cursor:
            doc_id = str(doc.get("_id", ""))
            doc_data = dict(doc)
            if "_id" in doc_data:
                del doc_data["_id"]
            results.append(MongoDocumentSnapshot(doc_id, doc_data))
        return results

class MockFirestoreClient:
    def __init__(self):
        try:
            self.client = pymongo.MongoClient(MONGO_URI, serverSelectionTimeoutMS=2000)
            # Trigger server selection to verify connectivity
            self.client.server_info()
            self.db_mongo = self.client[DATABASE_NAME]
            print(f"Successfully connected to MongoDB database '{DATABASE_NAME}' at {MONGO_URI}.")
        except Exception as e:
            print(f"MongoDB connection failed: {e}. Falling back to in-memory/JSON client.")
            # If MongoDB is not running, we could fallback to local mock dictionary in memory or raise error
            raise RuntimeError(f"Could not connect to MongoDB: {e}")

    def collection(self, name: str):
        return MongoCollection(self.db_mongo, name)

# Instantiate client database client instance db
db = MockFirestoreClient()
is_mock = False

