# OpenSpecimen Docker — SGS IICS-UNA

Deployment contenerizado de OpenSpecimen 9.x para el Sistema de Gestión de Seroteca.

## Requisitos

- Docker 24+
- Docker Compose v2+
- Git
- 4GB RAM mínimo (recomendado 8GB)
- 20GB espacio en disco

## Inicio Rápido (servidor nuevo)

```bash
# 1. Clonar este repositorio
git clone git@github.com:ortegaps/openspecimen-docker.git
cd openspecimen-docker

# 2. Ejecutar setup (crea directorios, permisos, .env, levanta servicios)
bash setup.sh
```

Eso es todo. El script `setup.sh` se encarga de:
- Verificar prerrequisitos (Docker, Compose)
- Crear directorios de volúmenes
- Aplicar permisos correctos (UID 999 para el usuario openspecimen del contenedor)
- Crear `.env` desde `.env.example` si no existe
- Levantar MySQL + OpenSpecimen
- Esperar a que Liquibase termine las migraciones
- Verificar que la app responda HTTP 200

### Si necesitás compilar desde código fuente

```bash
bash setup.sh --build
```

Esto clona el fork `ortegaps/openspecimen` en `src/openspecimen/` y ejecuta el build multi-stage (Gradle → WAR → imagen Docker). Toma ~10-15 minutos.

### Si necesitás una BD limpia desde cero

```bash
bash setup.sh --clean
```

Elimina los volúmenes y re-ejecuta todas las migraciones Liquibase.

## Acceso

| Servicio | URL | Usuario | Contraseña |
|----------|-----|---------|------------|
| OpenSpecimen | http://localhost:8080/openspecimen/ | admin | Login@123 |
| MySQL | localhost:3306 | openspecimen | sgs2026 |

> Cambiar la contraseña de admin en el primer acceso.

## Gestión del entorno

El script `manage.sh` centraliza todas las operaciones:

```bash
./manage.sh up          # Construir y levantar todo
./manage.sh start       # Reanudar servicios parados (sin rebuild)
./manage.sh stop        # Detener servicios (preserva datos)
./manage.sh down        # Parar y eliminar contenedores (preserva volúmenes)
./manage.sh rebuild     # Reconstruir imagen y reiniciar
./manage.sh logs        # Ver logs de OpenSpecimen en tiempo real
./manage.sh logs mysql  # Ver logs de MySQL
./manage.sh shell       # Abrir bash en el contenedor de la app
./manage.sh status      # Ver estado detallado
./manage.sh stats       # Uso de CPU/RAM en tiempo real
./manage.sh backup-db   # Respaldar base de datos
./manage.sh restore-db backups/archivo.sql  # Restaurar backup
./manage.sh validate    # Validar configuración
./manage.sh clean       # ELIMINAR TODO (contenedores, imágenes, datos)
```

### Diagnóstico

```bash
bash diagnose.sh
```

Verifica: contenedores, MySQL, Liquibase, variables de configuración, conectividad HTTP.

## Estructura del Proyecto

```
openspecimen-docker/
├── docker-compose.yml          # Orquestación: MySQL 8.0.26 + OpenSpecimen
├── Dockerfile.dev              # Multi-stage: JDK17 → Gradle → Tomcat 9
├── setup.sh                    # Inicialización automática (servidor nuevo)
├── manage.sh                   # Script de gestión (up/down/logs/backup...)
├── diagnose.sh                 # Diagnóstico del entorno
├── .env.example                # Variables de entorno (template)
├── config/
│   ├── openspecimen.xml        # Context descriptor (JNDI DataSource)
│   ├── openspecimen.properties # Configuración de la app
│   ├── context.xml             # Context global de Tomcat
│   ├── server.xml              # Configuración de Tomcat
│   └── docker-entrypoint-override.sh  # Override de entrypoint
├── scripts/
│   ├── backup.sh               # Backup completo (BD + config + data)
│   ├── deploy.sh               # Deploy automatizado
│   └── translate_openspecimen.py # Traductor EN→ES
├── src/
│   └── openspecimen/           # Código fuente (se clona con --build)
├── volumes/                    # Datos persistentes (no versionados)
│   ├── mysql_data/
│   ├── openspecimen_data/
│   ├── openspecimen_plugins/
│   └── tomcat_logs/
└── backups/                    # Backups de BD (no versionados)
```

## Configuración

### Variables de Entorno (.env)

| Variable | Descripción | Default |
|----------|-------------|---------|
| MYSQL_ROOT_PASSWORD | Password root MySQL | rootpass |
| MYSQL_DATABASE | Nombre de BD | openspecimen |
| MYSQL_USER | Usuario de BD | openspecimen |
| MYSQL_PASSWORD | Password de BD | sgs2026 |
| JAVA_OPTS | Opciones JVM | -Xms512m -Xmx3g |

### MySQL — Configuración crítica

Definida en `docker-compose.yml`, no modificar sin entender las consecuencias:

| Parámetro | Valor | Motivo |
|-----------|-------|--------|
| character-set-server | utf8 | utf8mb4 causa errores de índice en Liquibase |
| lower_case_table_names | 1 | Requerido por OpenSpecimen |
| log_bin_trust_function_creators | 1 | Requerido por Liquibase |
| default-authentication-plugin | mysql_native_password | Compatibilidad JDBC |
| max_allowed_packet | 256M | Imports grandes |
| innodb_default_row_format | dynamic | Evita errores de row size |

### Permisos de volúmenes

El contenedor de OpenSpecimen corre como usuario `openspecimen` (UID 999, GID 999). Los volúmenes montados deben tener este owner. El `setup.sh` lo hace automáticamente. Si tenés problemas de permisos:

```bash
chown -R 999:999 volumes/openspecimen_data volumes/openspecimen_plugins volumes/tomcat_logs
```

## Repos relacionados

| Repo | Propósito |
|------|-----------|
| [ortegaps/openspecimen-docker](https://github.com/ortegaps/openspecimen-docker) | Este repo — entorno Docker |
| [ortegaps/openspecimen](https://github.com/ortegaps/openspecimen) | Fork del código fuente (rama develop) |

## Troubleshooting

### La app no arranca (HTTP 404)
Verificar logs: `docker logs openspecimen-app 2>&1 | tail -30`. Si hay errores de "Permission denied", ejecutar:
```bash
chown -R 999:999 volumes/openspecimen_data volumes/openspecimen_plugins volumes/tomcat_logs
docker compose restart openspecimen
```

### Error: "Specified key was too long"
Asegurarse de usar `utf8` (no `utf8mb4`) en MySQL. Ya configurado en `docker-compose.yml`.

### Error: "Data source type is not specified"
Verificar que `config/openspecimen.properties` existe y contiene `datasource.jndi=jdbc/openspecimen` (sin prefijo `java:comp/env/`).

### Liquibase lock (app no arranca, queda esperando)
```bash
docker exec openspecimen-mysql mysql -u root -prootpass openspecimen \
  -e "UPDATE DATABASECHANGELOGLOCK SET LOCKED=0 WHERE ID=1;"
docker compose restart openspecimen
```

### Migraciones Liquibase fallan
Si la BD quedó inconsistente, lo más seguro es limpiar y empezar de cero:
```bash
bash setup.sh --clean
```

## Licencia

BSD-3-Clause (OpenSpecimen)
