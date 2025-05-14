#!/bin/bash

# Script to run filter join request on IMDB Clone Database

echo "Starting IMDB Clone Database filter join request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the filter join request file to the container
echo "Copying filter_join_request.sql file to the container..."
docker cp filter_join_request.sql postgres17:/tmp/filter_join_request.sql

# Execute the filter join request
echo "Executing filter join request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/filter_join_request.sql > filter_join_request_output2.txt

echo "Filter request finished. Results stored in filter_join_request_output.txt"
