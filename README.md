# IMDB Clone Database Project

This project contains a PostgreSQL database setup for an IMDB clone using Docker.

## Prerequisites

- Docker
- Docker Compose

## Getting Started

### 1. Start the Database

To start the PostgreSQL database container:

```bash
docker-compose up -d
```

This will start the PostgreSQL 17 container in detached mode.

### 2. Connect to the Database

To connect to the PostgreSQL database:

```bash
docker exec -it postgres17 psql -U admin -d imdb_clone
```

Connection details:
- Host: localhost
- Port: 5432 (default)
- Database: imdb_clone
- Username: admin
- Password: (set in docker-compose.yml)

### 3. Stop the Database

To stop the database container:

```bash
docker-compose down
```

## Troubleshooting

If you encounter any issues:

1. Check if the container is running:
```bash
docker ps
```

2. View container logs:
```bash
docker-compose logs
```

3. Ensure no other service is using port 5432

## Contributing

Feel free to submit issues and enhancement requests.