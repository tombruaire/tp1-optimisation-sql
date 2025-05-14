#!/bin/bash

# Script to run Index couvrants request on IMDB Clone Database

echo "Starting IMDB Clone Database Index couvrants request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the Index couvrants request file to the container
echo "Copying index_couvrants_request.sql file to the container..."
docker cp 6.sql postgres17:/tmp/6.sql

# Execute the Index couvrants request
echo "Executing index_couvrants_request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/6.sql > index_couvrants_request_output3.txt

echo "Index couvrants request finished. Results stored in index_couvrants_request_output.txt"
