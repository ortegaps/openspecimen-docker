#!/bin/bash
# manage.sh - Script de gestión para OpenSpecimen Docker
# Uso: ./manage.sh [comando]
# Fork: ortegaps - Rocky Linux 9 (Docker Compose v2)

set -e

# ============================================================================
# COLORES
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
COMPOSE_FILE="docker-compose.yml"
DOCKERFILE="Dockerfile.dev"
APP_SERVICE="openspecimen"
DB_SERVICE="mysql"
DB_USER="openspecimen"
DB_PASS="sgs2026"
DB_NAME="openspecimen"
APP_PORT="8080"
DB_PORT="3306"

# ============================================================================
# FUNCIONES DE OUTPUT
# ============================================================================
print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error()   { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info()    { echo -e "${BLUE}ℹ️  $1${NC}"; }

# ============================================================================
# VALIDAR PRERREQUISITOS
# ============================================================================
check_prerequisites() {
    print_header "Validando Prerrequisitos"

    if ! command -v docker &> /dev/null; then
        print_error "Docker no está instalado"
        exit 1
    fi
    print_success "Docker instalado: $(docker --version)"

    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose v2 no está instalado"
        exit 1
    fi
    print_success "Docker Compose instalado"

    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "$COMPOSE_FILE no encontrado. Ejecutar desde raíz del proyecto."
        exit 1
    fi
    print_success "$COMPOSE_FILE encontrado"

    if [ ! -f "$DOCKERFILE" ]; then
        print_error "$DOCKERFILE no encontrado."
        exit 1
    fi
    print_success "$DOCKERFILE encontrado"

    if [ ! -d "src/openspecimen" ]; then
        print_error "Código fuente no encontrado en src/openspecimen/"
        print_info "Ejecuta: git clone https://github.com/ortegaps/openspecimen.git src/openspecimen"
        exit 1
    fi
    print_success "Código fuente encontrado en src/openspecimen/"

    mkdir -p volumes/{mysql_data,openspecimen_data,tomcat_logs}
    mkdir -p config init-sql backups
    print_success "Directorios creados/verificados"
}

# ============================================================================
# LEVANTAR SERVICIOS
# ============================================================================
up() {
    print_header "Levantando Servicios"

    check_prerequisites

    print_info "Construyendo imagen Docker (multi-stage)..."
    docker compose build --no-cache

    print_info "Iniciando servicios..."
    docker compose up -d

    print_info "Esperando a que MySQL esté listo..."
    RETRIES=30
    COUNT=0
    until docker compose exec -T $DB_SERVICE mysqladmin ping -h localhost -u $DB_USER -p$DB_PASS --silent 2>/dev/null; do
        COUNT=$((COUNT + 1))
        if [ $COUNT -ge $RETRIES ]; then
            print_error "MySQL no respondió a tiempo"
            exit 1
        fi
        echo -n "."
        sleep 3
    done
    echo ""
    print_success "MySQL está listo"

    print_info "Esperando a que OpenSpecimen arranque en Tomcat..."
    RETRIES=40
    COUNT=0
    until curl -sf http://localhost:$APP_PORT/openspecimen/rest/ng/sessions 2>/dev/null | grep -q "." || \
          curl -sf http://localhost:$APP_PORT/openspecimen/ 2>/dev/null | grep -qiE "html|openspecimen"; do
        COUNT=$((COUNT + 1))
        if [ $COUNT -ge $RETRIES ]; then
            print_warning "OpenSpecimen no respondió a tiempo. Revisa los logs:"
            print_info "  ./manage.sh logs"
            break
        fi
        echo -n "."
        sleep 5
    done
    echo ""

    print_header "Estado de Servicios"
    docker compose ps

    print_header "URLs de Acceso"
    print_success "OpenSpecimen: http://localhost:$APP_PORT/openspecimen"
    print_success "MySQL (host):  localhost:$DB_PORT"
    print_info    "Usuario MySQL: $DB_USER"
    print_info    "Contraseña:    $DB_PASS"
}

# ============================================================================
# LEVANTAR SIN RECONSTRUIR (inicio rápido)
# ============================================================================
start() {
    print_header "Reanudando Servicios (sin reconstruir)"
    docker compose start
    print_success "Servicios reanudados"
    docker compose ps
}

# ============================================================================
# PARAR SERVICIOS (preserva datos y volúmenes)
# ============================================================================
stop() {
    print_header "Deteniendo Servicios (preservando datos)"
    docker compose stop
    print_success "Servicios detenidos"
}

# ============================================================================
# PARAR Y ELIMINAR CONTENEDORES (preserva volúmenes)
# ============================================================================
down() {
    print_header "Parando y eliminando contenedores"
    docker compose down
    print_success "Contenedores eliminados (datos preservados en volumes/)"
}

# ============================================================================
# RECONSTRUIR IMAGEN Y REINICIAR (útil tras cambiar código fuente)
# ============================================================================
rebuild() {
    print_header "Reconstruyendo imagen Docker"

    print_warning "Esto reconstruirá la imagen completa (multi-stage build)."
    print_info "Para actualizar código: actualiza src/openspecimen y ejecuta rebuild."

    docker compose down

    print_info "Construyendo imagen..."
    docker compose build --no-cache

    print_info "Levantando servicios..."
    docker compose up -d

    print_info "Esperando a que Tomcat arranque..."
    sleep 20

    print_header "Estado de Servicios"
    docker compose ps

    print_success "Rebuild completado"
    print_info "Revisa logs con: ./manage.sh logs"
}

# ============================================================================
# VER LOGS
# ============================================================================
logs() {
    SERVICE=${1:-$APP_SERVICE}
    print_header "Logs - $SERVICE"
    docker compose logs -f --tail=200 "$SERVICE"
}

# ============================================================================
# ABRIR SHELL EN CONTENEDOR
# ============================================================================
shell() {
    SERVICE=${1:-$APP_SERVICE}
    print_header "Shell en $SERVICE"
    docker compose exec "$SERVICE" /bin/bash
}

# ============================================================================
# ESTADO DE SERVICIOS
# ============================================================================
status() {
    print_header "Estado de Servicios"
    docker compose ps

    echo -e "\n${BLUE}Imágenes:${NC}"
    docker images | grep openspecimen || true

    echo -e "\n${BLUE}Volúmenes:${NC}"
    docker volume ls | grep openspecimen || true

    echo -e "\n${BLUE}Redes:${NC}"
    docker network ls | grep openspecimen || true

    echo -e "\n${BLUE}Uso de disco volumes/:${NC}"
    du -sh volumes/* 2>/dev/null || true
}

# ============================================================================
# ESTADÍSTICAS DE RECURSOS
# ============================================================================
stats() {
    print_header "Estadísticas de Recursos"
    docker stats --no-stream
}

# ============================================================================
# RESPALDAR BASE DE DATOS
# ============================================================================
backup_db() {
    print_header "Respaldando Base de Datos"

    BACKUP_FILE="backups/${DB_NAME}_backup_$(date +%Y%m%d_%H%M%S).sql"
    mkdir -p backups

    print_info "Respaldando a: $BACKUP_FILE"
    docker compose exec -T $DB_SERVICE mysqldump \
        -u $DB_USER -p$DB_PASS $DB_NAME > "$BACKUP_FILE"

    print_success "Backup completado"
    print_info "Archivo: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
}

# ============================================================================
# RESTAURAR BASE DE DATOS
# ============================================================================
restore_db() {
    BACKUP_FILE=$1

    if [ -z "$BACKUP_FILE" ]; then
        print_error "Especifica el archivo: ./manage.sh restore-db <archivo.sql>"
        echo ""
        echo "Backups disponibles:"
        ls -lh backups/*.sql 2>/dev/null || echo "  (ninguno)"
        exit 1
    fi

    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Archivo no encontrado: $BACKUP_FILE"
        exit 1
    fi

    print_header "Restaurando Base de Datos"
    print_warning "Esto sobrescribirá la base de datos actual: $DB_NAME"
    read -p "¿Continuar? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_info "Restaurando desde: $BACKUP_FILE"
        docker compose exec -T $DB_SERVICE mysql \
            -u $DB_USER -p$DB_PASS $DB_NAME < "$BACKUP_FILE"
        print_success "Base de datos restaurada"
    else
        print_info "Operación cancelada"
    fi
}

# ============================================================================
# LIMPIAR TODO
# ============================================================================
clean() {
    print_header "LIMPIANDO TODO"
    print_warning "Esto eliminará contenedores, imágenes, volúmenes y datos!"
    read -p "¿Estás seguro? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        docker compose down -v --rmi all 2>/dev/null || true
        rm -rf volumes/mysql_data volumes/openspecimen_data volumes/tomcat_logs
        print_success "Limpieza completada"
    else
        print_info "Operación cancelada"
    fi
}

# ============================================================================
# VALIDAR CONFIGURACIÓN
# ============================================================================
validate() {
    print_header "Validando Configuración"

    local files=("docker-compose.yml" "Dockerfile.dev" "config/openspecimen.properties" "config/context.xml")
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_success "$file existe"
        else
            print_error "$file NO encontrado"
        fi
    done

    if [ -d "src/openspecimen" ]; then
        print_success "Código fuente en src/openspecimen/"
        if [ -f "src/openspecimen/build.gradle" ]; then
            print_success "build.gradle encontrado"
        else
            print_error "build.gradle no encontrado en src/openspecimen/"
        fi
    else
        print_error "src/openspecimen/ no existe. Clona el repo."
    fi

    if docker ps &> /dev/null; then
        print_success "Docker daemon accesible"
    else
        print_error "No se puede acceder al Docker daemon"
    fi
}

# ============================================================================
# AYUDA
# ============================================================================
help() {
    cat << EOF

${BLUE}╔════════════════════════════════════════════════════════════════╗
║  OPENSPECIMEN DOCKER - SCRIPT DE GESTIÓN                       ║
║  Fork: ortegaps | Rocky Linux 9 | Docker Compose v2           ║
╚════════════════════════════════════════════════════════════════╝${NC}

${GREEN}COMANDOS PRINCIPALES:${NC}

  up              Construir imagen y levantar todos los servicios
  start           Reanudar servicios detenidos (sin reconstruir)
  stop            Detener servicios (preserva datos y volúmenes)
  down            Parar y eliminar contenedores (preserva volúmenes)
  rebuild         Reconstruir imagen completa y reiniciar

${GREEN}DESARROLLO:${NC}

  logs [srv]      Ver logs en tiempo real (default: openspecimen)
  shell [srv]     Abrir bash en contenedor  (default: openspecimen)
  stats           Ver uso de recursos en tiempo real
  status          Ver estado detallado de servicios

${GREEN}BASE DE DATOS:${NC}

  backup-db       Respaldar base de datos
  restore-db      Restaurar desde backup

${GREEN}UTILIDADES:${NC}

  validate        Validar archivos de configuración y estructura
  clean           LIMPIAR TODO (contenedores, imágenes, datos)
  help            Mostrar esta ayuda

${GREEN}EJEMPLOS:${NC}

  ./manage.sh up
  ./manage.sh logs
  ./manage.sh logs mysql
  ./manage.sh shell
  ./manage.sh rebuild
  ./manage.sh backup-db
  ./manage.sh restore-db backups/openspecimen_backup_20260305_120000.sql

EOF
}

# ============================================================================
# MAIN
# ============================================================================
COMMAND=${1:-help}

case "$COMMAND" in
    up)          up ;;
    start)       start ;;
    stop)        stop ;;
    down)        down ;;
    rebuild)     rebuild ;;
    logs)        logs "$2" ;;
    shell)       shell "$2" ;;
    status)      status ;;
    stats)       stats ;;
    clean)       clean ;;
    backup-db)   backup_db ;;
    restore-db)  restore_db "$2" ;;
    validate)    validate ;;
    help|--help|-h) help ;;
    *)
        print_error "Comando desconocido: $COMMAND"
        help
        exit 1
        ;;
esac

