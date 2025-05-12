#!/bin/bash

# Script to run performance tests on IMDB Clone Database

echo "Starting IMDB Clone Database performance tests..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the performance file to the container
echo "Copying performance.sql file to the container..."
docker cp sql/performance.sql postgres17:/tmp/performance.sql

# Execute the performance queries
echo "Executing performance queries..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/performance.sql > performance_output.txt

echo "Tests finished. Results stored in performance_output.txt"