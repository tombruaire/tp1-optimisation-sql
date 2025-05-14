#!/bin/bash

# Script to run Index partiels request on IMDB Clone Database

echo "Starting IMDB Clone Database Index partiels request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the Index partiels request file to the container
echo "Copying index_partiels_request.sql file to the container..."
docker cp 4.sql postgres17:/tmp/4.sql

# Execute the Index partiels request
echo "Executing index_partiels_request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/4.sql > index_partiels_request_output2.txt

echo "Index partiels request finished. Results stored in index_partiels_request_output.txt"
