#!/bin/bash

# Script to run Index composites request on IMDB Clone Database

echo "Starting IMDB Clone Database Index composites request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the Index composites request file to the container
echo "Copying index_composites_request.sql file to the container..."
docker cp 3.sql postgres17:/tmp/3.sql

# Execute the Index composites request
echo "Executing index_composites_request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/3.sql > index_composites_request_output4.txt

echo "Index composites request finished. Results stored in index_composites_request_output.txt"
