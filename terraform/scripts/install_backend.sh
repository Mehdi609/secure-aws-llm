#!/bin/bash

apt update -y
apt install -y python3-pip nginx git

# Install FastAPI
pip3 install fastapi uvicorn

# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama
ollama serve &

# Basic FastAPI app
cat <<EOF > /home/azureuser/app.py
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "AI Backend running"}
EOF

uvicorn app:app --host 0.0.0.0 --port 8000 &