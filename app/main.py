from fastapi import FastAPI
from database import get_data

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "FastAPI fonctionne"}

@app.get("/items")
def items():
    return get_data()
