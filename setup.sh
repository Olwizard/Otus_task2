#!/bin/bash

# === Загрузка переменных окружения из файла .env ===
ENV_FILE="/home/cyberops/ml_ops/.env"
if [ -f "$ENV_FILE" ]; then
  echo "Файл $ENV_FILE найден."
  cat "$ENV_FILE"
  export $(grep -v '^#' "$ENV_FILE" | xargs)
  echo "Файл $ENV_FILE загружен."
else
  echo "Ошибка: Файл $ENV_FILE не найден."
  exit 1
fi

# Проверка загруженных переменных
echo "MINIO_ENDPOINT_URL=${MINIO_ENDPOINT_URL}"
echo "MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}"
echo "MINIO_SECRET_KEY=${MINIO_SECRET_KEY}"
# sudo apt-get update -y
# sudo apt-get install -y docker.io docker-compose
mkdir -p ~/fastapi-service && cd ~/fastapi-service
cat <<EOF > docker-compose.yml

services:
  fastapi_terra:
    image: tiangolo/uvicorn-gunicorn-fastapi:python3.9
    container_name: fastapi_terra
    ports:
      - "8445:80"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/appdb
      - MINIO_ENDPOINT=${MINIO_ENDPOINT_URL}
      - MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
      - MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
      - MINIO_SECURE="False"         # Внутри Docker-сети используем HTTP
    networks:
      internal:
        ipv4_address: 172.32.0.4
    depends_on:
      - db

  db:
    image: postgres:14
    container_name: postgres_terra
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: appdb
    networks:
      internal:
        ipv4_address: 172.32.0.5
  minio:
    image: minio/minio
    container_name: minio_terra
    restart: always
    command: server /data --address ":9007" --console-address ":9008"
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY}
    networks:
      internal:
         ipv4_address: 172.32.0.6

networks:
  internal:
    driver: bridge
    ipam:
      config:
        - subnet: 172.32.0.0/27
          gateway: 172.32.0.1

EOF
docker-compose up -d