#!/bin/bash

# Script to run aggregation sort request on IMDB Clone Database

echo "Starting IMDB Clone Database aggregation sort request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the aggregation sort request file to the container
echo "Copying aggregation_sort_request.sql file to the container..."
docker cp aggregation_sort_request.sql postgres17:/tmp/aggregation_sort_request.sql

# Execute the aggregation sort request
echo "Executing aggregation sort request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/aggregation_sort_request.sql > aggregation_sort_request_output2.txt

echo "Aggregation sort request finished. Results stored in aggregation_sort_request_output.txt"
