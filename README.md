# OpenSpecimen Docker — SGS IICS-UNA

Deployment contenerizado de OpenSpecimen 9.x para el Sistema de Gestión de Seroteca.

## Requisitos

- Docker 24+
- Docker Compose v2+
- Git
- 4GB RAM mínimo (recomendado 8GB)
- 20GB espacio en disco

## Inicio Rápido (servidor nuevo)

    git clone git@github.com:ortegaps/openspecimen-docker.git
    cd openspecimen-docker && bash setup.sh

El script setup.sh se encarga de todo: verifica prerrequisitos, crea directorios, aplica permisos (UID 999), crea .env, levanta servicios, espera migraciones Liquibase y verifica HTTP 200.

Compilar desde fuente: bash setup.sh --build
BD limpia desde cero: bash setup.sh --clean

## Acceso

- OpenSpecimen: http://localhost:8080/openspecimen/ (admin / Login@123)
- MySQL: localhost:3306 (openspecimen / sgs2026)

## Gestión

    ./manage.sh up          # Construir y levantar
    ./manage.sh start       # Reanudar sin rebuild
    ./manage.sh stop        # Detener (preserva datos)
    ./manage.sh down        # Eliminar contenedores
    ./manage.sh rebuild     # Reconstruir imagen
    ./manage.sh logs        # Logs OpenSpecimen
    ./manage.sh logs mysql  # Logs MySQL
    ./manage.sh shell       # Bash en contenedor
    ./manage.sh status      # Estado detallado
    ./manage.sh backup-db   # Respaldar BD
    ./manage.sh restore-db backups/archivo.sql
    ./manage.sh clean       # ELIMINAR TODO

Diagnóstico: bash diagnose.sh

## Estructura

    openspecimen-docker/
    ├── docker-compose.yml
    ├── Dockerfile.dev
    ├── setup.sh
    ├── manage.sh
    ├── diagnose.sh
    ├── .env.example
    ├── config/
    │   ├── openspecimen.xml
    │   ├── openspecimen.properties
    │   ├── context.xml
    │   └── server.xml
    ├── scripts/
    ├── src/openspecimen/        # Con --build
    ├── volumes/                 # Datos persistentes
    └── backups/

## Configuración MySQL

- character-set-server=utf8 (utf8mb4 causa errores de índice)
- lower_case_table_names=1 (requerido por OpenSpecimen)
- log_bin_trust_function_creators=1 (requerido por Liquibase)
- default-authentication-plugin=mysql_native_password
- max_allowed_packet=256M

## Permisos

El contenedor corre como UID 999. Si hay errores de permisos:

    chown -R 999:999 volumes/openspecimen_data volumes/openspecimen_plugins volumes/tomcat_logs

## Repos relacionados

- ortegaps/openspecimen-docker - Entorno Docker (este repo)
- ortegaps/openspecimen - Fork del código fuente (rama develop)

## Troubleshooting

HTTP 404 / Permission denied:
    chown -R 999:999 volumes/openspecimen_data volumes/openspecimen_plugins volumes/tomcat_logs
    docker compose restart openspecimen

Liquibase lock:
    docker exec openspecimen-mysql mysql -u root -prootpass openspecimen -e "UPDATE DATABASECHANGELOGLOCK SET LOCKED=0 WHERE ID=1;"
    docker compose restart openspecimen

BD inconsistente:
    bash setup.sh --clean

## Licencia
BSD-3-Clause (OpenSpecimen)
