FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
# Install system dependencies (IMPORTANT)
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*


RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Run the FastAPI server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
