#!/bin/bash

# Script to run simple request on IMDB Clone Database

echo "Starting IMDB Clone Database simple request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the simple request file to the container
echo "Copying simple-request.sql file to the container..."
docker cp simple-request.sql postgres17:/tmp/simple-request.sql

# Execute the simple request
echo "Executing simple request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/simple-request.sql > simple_request_output3.txt

echo "Simple request finished. Results stored in simple_request_output.txt"
