#!/bin/bash

# Script to run benchmark tests on IMDB Clone Database

echo "Starting IMDB Clone Database benchmark tests..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the benchmark file to the container
echo "Copying benchmark.sql file to the container..."
docker cp sql/benchmark.sql postgres17:/tmp/benchmark.sql

# Execute the benchmark queries
echo "Executing benchmark queries..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/benchmark.sql > benchmark_output.txt

echo "Tests finished. Results stored in benchmark_output.txt"
