#!/bin/bash

# Script to run Index d'expressions request on IMDB Clone Database

echo "Starting IMDB Clone Database Index d'expressions request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the Index d'expressions request file to the container
echo "Copying index_expressions_request.sql file to the container..."
docker cp 5.sql postgres17:/tmp/5.sql

# Execute the Index d'expressions request
echo "Executing index_expressions_request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/5.sql > index_expressions_request_output3.txt

echo "Index d'expressions request finished. Results stored in index_expressions_request_output.txt"
