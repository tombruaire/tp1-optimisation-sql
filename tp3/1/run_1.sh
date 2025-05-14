#!/bin/bash

# Script to run Index B-tree request on IMDB Clone Database

echo "Starting IMDB Clone Database Index B-tree request..."

# Check if Docker is running
if ! docker ps | grep -q postgres17; then
    echo "PostgreSQL container not found. Starting containers..."
    docker-compose up -d
    echo "Waiting for 10 seconds for PostgreSQL to start completely..."
    sleep 10
else
    echo "PostgreSQL container already running."
fi

# Copy the Index B-tree request file to the container
echo "Copying index_btree_request.sql file to the container..."
docker cp 1.sql postgres17:/tmp/1.sql

# Execute the Index B-tree request
echo "Executing index_btree_request..."
docker exec -i postgres17 psql -U admin -d imdb_clone -f /tmp/1.sql > index_btree_request_output.txt

echo "Index B-tree request finished. Results stored in index_btree_request_output.txt"
