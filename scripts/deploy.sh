#!/bin/bash
set -e

echo "=== Deploy OpenSpecimen ==="

# Crear directorios
mkdir -p volumes/{mysql_data,openspecimen_data,openspecimen_plugins,tomcat_logs}

# Build si es necesario
if [[ "$1" == "--build" ]]; then
    echo "Building image..."
    docker compose build --no-cache
fi

# Deploy
echo "Starting services..."
docker compose up -d

# Esperar
echo "Waiting for services (120s)..."
sleep 120

# Verificar
echo "=== Status ==="
docker compose ps
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:8080/openspecimen/

echo ""
echo "OpenSpecimen disponible en: http://localhost:8080/openspecimen/"
echo "Usuario: admin / Password: Login@123"
