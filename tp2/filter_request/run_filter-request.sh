#!/bin/bash

# Script to run filter request on IMDB Clone Database

echo "Starting IMDB Clone Database filter request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the filter request file to the container
echo "Copying filter_request.sql file to the container..."
docker cp filter_request.sql postgres17:/tmp/filter_request.sql

# Execute the filter request
echo "Executing filter request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/filter_request.sql > filter_request_output3.txt

echo "Filter request finished. Results stored in filter_request_output.txt"
