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

class InMemoryDocumentSnapshot:
    def __init__(self, doc_id: str, data: Optional[Dict[str, Any]]):
        self.id = doc_id
        self._data = data
        self.exists = data is not None

    def to_dict(self) -> Optional[Dict[str, Any]]:
        return self._data


class InMemoryQuery:
    def __init__(self, store: Dict[str, Dict[str, Dict[str, Any]]], collection_name: str, filters: Optional[Dict[str, Any]] = None):
        self._store = store
        self._collection_name = collection_name
        self._filters = filters or {}

    def where(self, field: str, op: str, value: Any):
        new_filters = dict(self._filters)
        if op == "==":
            new_filters[field] = value
        elif op == "<":
            new_filters[field] = {"$lt": value}
        elif op == ">":
            new_filters[field] = {"$gt": value}
        return InMemoryQuery(self._store, self._collection_name, new_filters)

    def get(self) -> List[InMemoryDocumentSnapshot]:
        results = []
        for doc_id, doc_data in self._store.get(self._collection_name, {}).items():
            if self._matches(doc_data):
                results.append(InMemoryDocumentSnapshot(str(doc_id), dict(doc_data)))
        return results

    def _matches(self, doc_data: Dict[str, Any]) -> bool:
        for field, expected in self._filters.items():
            if isinstance(expected, dict) and "$lt" in expected:
                if doc_data.get(field) is None or doc_data.get(field) >= expected["$lt"]:
                    return False
            elif isinstance(expected, dict) and "$gt" in expected:
                if doc_data.get(field) is None or doc_data.get(field) <= expected["$gt"]:
                    return False
            elif doc_data.get(field) != expected:
                return False
        return True


class InMemoryDocument:
    def __init__(self, store: Dict[str, Dict[str, Dict[str, Any]]], collection_name: str, doc_id: str):
        self._store = store
        self._collection_name = collection_name
        self.doc_id = str(doc_id)

    def get(self) -> InMemoryDocumentSnapshot:
        doc_data = self._store.get(self._collection_name, {}).get(self.doc_id)
        if doc_data is None:
            return InMemoryDocumentSnapshot(self.doc_id, None)
        return InMemoryDocumentSnapshot(self.doc_id, dict(doc_data))

    def set(self, data: Dict[str, Any], merge: bool = False):
        collection_data = self._store.setdefault(self._collection_name, {})
        existing = dict(collection_data.get(self.doc_id, {})) if self.doc_id in collection_data else {}
        if merge:
            existing.update(data)
            collection_data[self.doc_id] = existing
        else:
            collection_data[self.doc_id] = dict(data)

    def update(self, data: Dict[str, Any]):
        self.set(data, merge=True)

    def delete(self):
        self._store.get(self._collection_name, {}).pop(self.doc_id, None)


class InMemoryCollection:
    def __init__(self, store: Dict[str, Dict[str, Dict[str, Any]]], name: str):
        self._store = store
        self.name = name

    def document(self, doc_id: str):
        return InMemoryDocument(self._store, self.name, doc_id)

    def where(self, field: str, op: str, value: Any):
        return InMemoryQuery(self._store, self.name).where(field, op, value)

    def get(self) -> List[InMemoryDocumentSnapshot]:
        results = []
        for doc_id, doc_data in self._store.get(self.name, {}).items():
            results.append(InMemoryDocumentSnapshot(str(doc_id), dict(doc_data)))
        return results


class MockFirestoreClient:
    def __init__(self):
        self._store: Dict[str, Dict[str, Dict[str, Any]]] = {}
        try:
            self.client = pymongo.MongoClient(MONGO_URI, serverSelectionTimeoutMS=2000)
            self.client.server_info()
            self.db_mongo = self.client[DATABASE_NAME]
            print(f"Successfully connected to MongoDB database '{DATABASE_NAME}' at {MONGO_URI}.")
            self._use_mongo = True
        except Exception as e:
            print(f"MongoDB connection failed: {e}. Falling back to in-memory/JSON client.")
            self._use_mongo = False

    def collection(self, name: str):
        if self._use_mongo:
            return MongoCollection(self.db_mongo, name)
        return InMemoryCollection(self._store, name)

# Instantiate client database client instance db
db = MockFirestoreClient()
is_mock = not db._use_mongo

