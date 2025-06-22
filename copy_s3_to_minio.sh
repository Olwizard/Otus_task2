#!/bin/bash

# === Проверка наличия AWS CLI ===
echo "Проверка наличия AWS CLI..."
if command -v aws &> /dev/null; then
  echo "AWS CLI уже установлен. Пропуск процесса установки."
else
  echo "AWS CLI не найден. Начинаем установку..."

  # === Установка AWS CLI ===
  echo "Установка AWS CLI..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"  -o "awscliv2.zip"
  if [ $? -ne 0 ]; then
    echo "Ошибка при скачивании AWS CLI."
    exit 1
  fi

  unzip -o awscliv2.zip # Добавлен флаг -o для автоматической перезаписи файлов
  if [ $? -ne 0 ]; then
    echo "Ошибка при распаковке AWS CLI."
    exit 1
  fi

  sudo ./aws/install
  if [ $? -ne 0 ]; then
    echo "Ошибка при установке AWS CLI."
    exit 1
  fi
  echo "AWS CLI успешно установлен."
fi

# === Отладка: Вывод текущей рабочей директории ===
echo "Текущая рабочая директория:"
pwd

# === Загрузка переменных окружения из файла .env ===
ENV_FILE="/home/cyberops/ml_ops/.env"
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
  echo "Файл $ENV_FILE загружен."
else
  echo "Ошибка: Файл $ENV_FILE не найден."
  exit 1
fi

# === Настройка профиля Yandex Cloud ===
echo "Настройка профиля Yandex Cloud..."
aws configure set aws_access_key_id "$YANDEX_AWS_ACCESS_KEY_ID" --profile yandex
aws configure set aws_secret_access_key "$YANDEX_AWS_SECRET_ACCESS_KEY" --profile yandex
aws configure set region "$YANDEX_AWS_REGION" --profile yandex
aws configure set output "json" --profile yandex
echo "Профиль Yandex Cloud настроен."

# === Настройки для Yandex Object Storage ===
YANDEX_BUCKET_NAME=${YANDEX_AWS_BUCKET_NAME}
YANDEX_FILE_KEY=${YANDEX_AWS_FILE_KEY}  # Имя файла в Yandex S3
YANDEX_ENDPOINT_URL=${YANDEX_AWS_ENDPOINT_URL} 

# === Настройки для MinIO ===
MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
MINIO_ENDPOINT_URL=${MINIO_ENDPOINT_URL}  # API MinIO
MINIO_BUCKET_NAME=${MINIO_BUCKET_NAME}  # Бакет в MinIO
MINIO_FILE_KEY=${MINIO_FILE_KEY}  # Имя файла в MinIO

# Локальный путь для временного хранения файла
LOCAL_FILE_PATH="./ml_ops/tmp/temp_file.csv"

# Проверка наличия обязательных переменных
if [[ -z "$YANDEX_AWS_ACCESS_KEY_ID" || -z "$YANDEX_AWS_SECRET_ACCESS_KEY" || -z "$YANDEX_AWS_REGION" || \
      -z "$MINIO_ACCESS_KEY" || -z "$MINIO_SECRET_KEY" || -z "$MINIO_BUCKET_NAME" ]]; then
  echo "Ошибка: Необходимо задать все обязательные переменные в файле .env."
  exit 1
fi

# === Шаг 1: Скачивание файла из Yandex S3 ===
echo "Скачивание файла $YANDEX_FILE_KEY из Yandex S3..."
aws s3 cp "s3://$YANDEX_BUCKET_NAME/$YANDEX_FILE_KEY" "$LOCAL_FILE_PATH" \
  --endpoint-url="$YANDEX_ENDPOINT_URL" \
  --profile yandex

if [ $? -ne 0 ]; then
  echo "Ошибка при скачивании файла из Yandex S3."
  exit 1
fi
echo "Файл успешно скачан в $LOCAL_FILE_PATH."

# === Шаг 2: Создание бакета в MinIO (если он не существует) ===
echo "Проверка существования бакета $MINIO_BUCKET_NAME в MinIO..."
aws s3api head-bucket --bucket "$MINIO_BUCKET_NAME" \
  --endpoint-url="$MINIO_ENDPOINT_URL" \
  --profile minio 2>/dev/null

if [ $? -ne 0 ]; then
  echo "Бакет $MINIO_BUCKET_NAME не существует. Создаем бакет..."
  aws s3 mb "s3://$MINIO_BUCKET_NAME" \
    --endpoint-url="$MINIO_ENDPOINT_URL" \
    --profile minio

  if [ $? -ne 0 ]; then
    echo "Ошибка при создании бакета $MINIO_BUCKET_NAME в MinIO."
    exit 1
  fi
  echo "Бакет $MINIO_BUCKET_NAME успешно создан."
else
  echo "Бакет $MINIO_BUCKET_NAME уже существует."
fi

# === Шаг 3: Загрузка файла в MinIO ===
echo "Загрузка файла $LOCAL_FILE_PATH в MinIO бакет $MINIO_BUCKET_NAME как $MINIO_FILE_KEY..."

# Создаем профиль MinIO
aws configure set aws_access_key_id "$MINIO_ACCESS_KEY" --profile minio
aws configure set aws_secret_access_key "$MINIO_SECRET_KEY" --profile minio
aws configure set region "us-east-1" --profile minio  # Регион MinIO (фиктивный)

aws s3 cp "$LOCAL_FILE_PATH" "s3://$MINIO_BUCKET_NAME/$MINIO_FILE_KEY" \
  --endpoint-url="$MINIO_ENDPOINT_URL" \
  --profile minio

if [ $? -ne 0 ]; then
  echo "Ошибка при загрузке файла в MinIO."
  exit 1
fi
echo "Файл успешно загружен в MinIO бакет $MINIO_BUCKET_NAME как $MINIO_FILE_KEY."

# === Очистка: Удаление временного файла ===
rm -f "$LOCAL_FILE_PATH"
if [ $? -eq 0 ]; then
  echo "Временный файл $LOCAL_FILE_PATH удален."
else
  echo "Ошибка при удалении временного файла."
fi