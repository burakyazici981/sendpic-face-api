# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application
COPY railway_main.py .
COPY face_recognition_server/ ./face_recognition_server/

# Create necessary directories
RUN mkdir -p uploads logs

# Expose port
EXPOSE 8000

# Set environment variables
ENV PORT=8000
ENV PYTHONPATH=/app

# Run the application
CMD ["python", "railway_main.py"]
