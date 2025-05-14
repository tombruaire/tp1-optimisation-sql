#!/bin/bash

# Script to run Index Hash request on IMDB Clone Database

echo "Starting IMDB Clone Database Index Hash request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the Index Hash request file to the container
echo "Copying index_hash_request.sql file to the container..."
docker cp 2.sql postgres17:/tmp/2.sql

# Execute the Index Hash request
echo "Executing index_hash_request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/2.sql > index_hash_request_output2.txt

echo "Index Hash request finished. Results stored in index_hash_request_output.txt"
