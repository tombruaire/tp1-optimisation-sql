#!/bin/bash

# Script to run Recherche textuelle request on IMDB Clone Database

echo "Starting IMDB Clone Database Recherche textuelle request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the Recherche textuelle request file to the container
echo "Copying search_request.sql file to the container..."
docker cp 7.sql postgres17:/tmp/7.sql

# Execute the Recherche textuelle request
echo "Executing search_request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/7.sql > search_request_output4.txt

echo "Search request finished. Results stored in search_request_output.txt"
