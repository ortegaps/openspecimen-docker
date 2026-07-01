#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }
fail() { echo -e "  ${RED}❌ $1${NC}"; exit 1; }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "  ${BLUE}ℹ️  $1${NC}"; }

header() {
    echo ""
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║  $1${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

DO_BUILD=false
DO_CLEAN=false
for arg in "$@"; do
    case $arg in
        --build) DO_BUILD=true ;;
        --clean) DO_CLEAN=true ;;
        --help|-h) echo "Uso: bash setup.sh [--build] [--clean]"; exit 0 ;;
    esac
done

OS_UID=999
OS_GID=999

header "1. VERIFICANDO PRERREQUISITOS"

command -v docker &>/dev/null && ok "Docker: $(docker --version | head -1)" || fail "Docker no instalado"
docker info &>/dev/null && ok "Docker daemon corriendo" || fail "Docker daemon no responde"
docker compose version &>/dev/null 2>&1 && ok "Docker Compose: $(docker compose version 2>/dev/null | head -1)" || fail "Docker Compose v2 no encontrado"
[ -f "docker-compose.yml" ] && ok "docker-compose.yml encontrado" || fail "docker-compose.yml no encontrado. Ejecutá desde openspecimen-docker/"
[ -f "Dockerfile.dev" ] && ok "Dockerfile.dev encontrado" || fail "Dockerfile.dev no encontrado"

header "2. CREANDO DIRECTORIOS"

for dir in volumes/mysql_data volumes/openspecimen_data volumes/openspecimen_plugins volumes/tomcat_logs backups src; do
    mkdir -p "$dir"
    ok "$dir"
done

header "3. PERMISOS (UID=$OS_UID)"

for dir in volumes/openspecimen_data volumes/openspecimen_plugins volumes/tomcat_logs; do
    chown -R ${OS_UID}:${OS_GID} "$dir"
    ok "$dir → ${OS_UID}:${OS_GID}"
done

header "4. ARCHIVO .env"

if [ -f ".env" ]; then
    ok ".env ya existe"
elif [ -f ".env.example" ]; then
    cp .env.example .env
    ok ".env creado desde .env.example"
else
    cat > .env << 'ENVBLOCK'
MYSQL_ROOT_PASSWORD=rootpass
MYSQL_DATABASE=openspecimen
MYSQL_USER=openspecimen
MYSQL_PASSWORD=sgs2026
JAVA_OPTS=-Xms512m -Xmx3g -Dapp.home=/usr/local/tomcat
ENVBLOCK
    ok ".env creado con valores por defecto"
fi

header "5. CÓDIGO FUENTE"

if [ -d "src/openspecimen" ] && [ -f "src/openspecimen/build.gradle" ]; then
    ok "src/openspecimen/ encontrado"
elif [ "$DO_BUILD" = true ]; then
    info "Clonando fork..."
    git clone --depth 1 --branch develop https://github.com/ortegaps/openspecimen.git src/openspecimen
    ok "Código clonado"
else
    info "src/openspecimen/ no existe (no necesario si la imagen ya está construida)"
fi

header "6. IMAGEN DOCKER"

if docker images -q ortegaps/openspecimen:dev 2>/dev/null | grep -q .; then
    ok "Imagen ortegaps/openspecimen:dev encontrada"
elif [ "$DO_BUILD" = true ]; then
    info "Se construirá en el paso 8"
else
    fail "Imagen no encontrada. Usá --build para compilar."
fi

header "7. LIMPIEZA"

if [ "$DO_CLEAN" = true ]; then
    docker compose down 2>/dev/null || true
    rm -rf volumes/mysql_data/* volumes/openspecimen_data/* volumes/tomcat_logs/*
    for dir in volumes/openspecimen_data volumes/openspecimen_plugins volumes/tomcat_logs; do
        chown -R ${OS_UID}:${OS_GID} "$dir"
    done
    ok "Volúmenes limpiados y permisos re-aplicados"
else
    info "Sin limpieza (usá --clean para BD desde cero)"
fi

header "8. BUILD"

if [ "$DO_BUILD" = true ]; then
    [ -f "src/openspecimen/build.gradle" ] || fail "src/openspecimen/build.gradle no encontrado"
    info "Construyendo imagen (10-15 min)..."
    docker compose build --no-cache
    ok "Imagen construida"
else
    info "Sin build (usá --build para compilar desde fuente)"
fi

header "9. LEVANTANDO SERVICIOS"

docker compose down 2>/dev/null || true
docker compose up -d

info "Esperando MySQL..."
COUNT=0
until docker exec openspecimen-mysql mysqladmin ping -h localhost -u openspecimen -psgs2026 --silent 2>/dev/null; do
    COUNT=$((COUNT + 1))
    [ $COUNT -ge 30 ] && fail "MySQL no respondió"
    echo -n "."
    sleep 3
done
echo ""
ok "MySQL listo"

info "Esperando OpenSpecimen (3-5 min para migraciones)..."
COUNT=0
HTTP_CODE=0
until [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; do
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge 60 ]; then
        warn "OpenSpecimen no respondió en 5 minutos"
        info "Revisá: docker logs openspecimen-app 2>&1 | tail -30"
        break
    fi
    echo -n "."
    sleep 5
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8080/openspecimen/ 2>/dev/null || echo "000")
done
echo ""

[ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] && ok "OpenSpecimen respondiendo (HTTP $HTTP_CODE)" || warn "Aún no responde (HTTP $HTTP_CODE)"

header "10. RESUMEN"

docker compose ps
echo ""
VM_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo -e "  ${BOLD}Accesos:${NC}"
echo -e "    Local:   ${GREEN}http://localhost:8080/openspecimen/${NC}"
[ -n "$VM_IP" ] && echo -e "    Externo: ${GREEN}http://${VM_IP}:8080/openspecimen/${NC}"
echo ""
echo -e "  ${BOLD}Credenciales:${NC}"
echo -e "    OpenSpecimen: admin / Login@123"
echo -e "    MySQL: openspecimen / sgs2026"
echo ""
echo -e "  ${BOLD}Comandos:${NC}"
echo -e "    ./manage.sh logs       Logs en tiempo real"
echo -e "    ./manage.sh status     Estado de servicios"
echo -e "    ./manage.sh backup-db  Respaldar BD"
echo -e "    bash diagnose.sh       Diagnóstico completo"
echo ""
echo -e "${BLUE}  Setup completado: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
