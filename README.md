# OpenSpecimen Docker

Deployment de OpenSpecimen en Docker, listo para CI/CD y GitOps.

## Requisitos

- Docker 24+
- Docker Compose v2+
- 4GB RAM mínimo (recomendado 8GB)
- 20GB espacio en disco

## Inicio Rápido
```bash
# Clonar repositorio
git clone https://github.com/ortegaps/openspecimen.git
cd openspecimen

# Crear directorios de volúmenes
mkdir -p volumes/{mysql_data,openspecimen_data,openspecimen_plugins,tomcat_logs}

# Construir imagen (primera vez, ~10 minutos)
docker compose build

# Levantar servicios
docker compose up -d

# Ver logs (esperar ~3 minutos para migraciones)
docker compose logs -f openspecimen
```

## Acceso

- **URL**: http://localhost:8080/openspecimen/
- **Usuario**: admin
- **Password**: Login@123 (cambiar en primer acceso)

## Estructura del Proyecto
```
openspecimen/
├── docker-compose.yml      # Orquestación de servicios
├── Dockerfile.dev          # Build de imagen OpenSpecimen
├── config/
│   ├── openspecimen.xml        # Context descriptor (JNDI)
│   └── openspecimen.properties # Configuración de la app
├── src/
│   └── openspecimen/           # Código fuente (fork)
├── volumes/
│   ├── mysql_data/             # Datos MySQL (persistente)
│   ├── openspecimen_data/      # Archivos de datos
│   ├── openspecimen_plugins/   # Plugins
│   └── tomcat_logs/            # Logs
└── scripts/
    ├── backup.sh               # Script de backup
    └── deploy.sh               # Script de deploy
```

## Configuración

### Variables de Entorno

| Variable | Descripción | Default |
|----------|-------------|---------|
| MYSQL_ROOT_PASSWORD | Password root MySQL | rootpass |
| MYSQL_DATABASE | Nombre de BD | openspecimen |
| MYSQL_USER | Usuario de BD | openspecimen |
| MYSQL_PASSWORD | Password de BD | sgs2026 |
| JAVA_OPTS | Opciones JVM | -Xms512m -Xmx3g |

### MySQL

Configuración crítica en `docker-compose.yml`:
- `character-set-server=utf8` (NO utf8mb4, causa errores de índice)
- `lower_case_table_names=1` (requerido)
- `log_bin_trust_function_creators=1` (para Liquibase)
- `innodb_default_row_format=dynamic`

## CI/CD

### GitHub Actions (ejemplo)
```yaml
name: Build and Deploy
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
      
      - name: Build image
        run: docker compose build
      
      - name: Push to registry
        run: |
          docker tag ortegaps/openspecimen:dev ghcr.io/${{ github.repository }}:latest
          docker push ghcr.io/${{ github.repository }}:latest
```

## Backup y Restore
```bash
# Backup
./scripts/backup.sh

# Restore
./manage.sh restore-db backups/openspecimen_backup_20260308_120000_db.sql
```

## Troubleshooting

### Error: "Specified key was too long"
- Usar `utf8` en lugar de `utf8mb4` en MySQL
- Ya configurado en docker-compose.yml

### Error: "Data source type is not specified"
- Verificar que `openspecimen.properties` existe en `/usr/local/tomcat/conf/`
- Verificar `datasource.jndi=jdbc/openspecimen` (sin `java:comp/env/`)

### Liquibase lock
```bash
docker exec openspecimen-mysql mysql -u root -prootpass openspecimen \
  -e "DELETE FROM DATABASECHANGELOGLOCK;"
```

## Licencia

BSD-3-Clause (OpenSpecimen)
