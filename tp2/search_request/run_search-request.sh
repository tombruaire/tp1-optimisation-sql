#!/bin/bash

# Script to run search request on IMDB Clone Database

echo "Starting IMDB Clone Database search request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the search request file to the container
echo "Copying search_request.sql file to the container..."
docker cp search_request.sql postgres17:/tmp/search_request.sql

# Execute the search request
echo "Executing search request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/search_request.sql > search_request_output.txt

echo "Search request finished. Results stored in search_request_output.txt"
