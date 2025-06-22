terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.4"
    }
  }
}

provider "null" {}

# Ресурс для выполнения второго скрипта (копирование файла из Yandex S3 в MinIO)
resource "null_resource" "copy_s3_to_minio" {

  connection {
    type        = "ssh"
    host        = "0.0.0.0" # IP-адрес сервера
    user        = "cyberops"     # Пользователь для подключения
    private_key = file("~/.ssh/cyber.rsa") # Путь к приватному ключу SSH
  }

  # Создание директории перед копированием файла
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/cyberops/ml_ops", # Создаем директорию, если она не существует
    ]
  }

  # Копирование файла .env на удаленный сервер
  provisioner "file" {
    source      = "${path.module}/.env" # Локальный путь к файлу .env
    destination = "/home/cyberops/ml_ops/.env" # Путь на удаленном сервере
  }

  # Копирование второго скрипта на удаленный сервер
  provisioner "file" {
    source      = "${path.module}/copy_s3_to_minio.sh" # Локальный путь к скрипту
    destination = "/home/cyberops/ml_ops/copy_s3_to_minio.sh" # Путь на удаленном сервере
  }

  # Выполнение второго скрипта на удаленном сервере
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/cyberops/ml_ops/copy_s3_to_minio.sh", # Делаем скрипт исполняемым
      "ls -l /home/cyberops/ml_ops/",                      # Проверяем, что файлы скопированы
      "/home/cyberops/ml_ops/copy_s3_to_minio.sh"          # Запускаем скрипт
    ]
  }
}