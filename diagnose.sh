#!/bin/bash
# ============================================
# OpenSpecimen Diagnostic Script
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "============================================"
echo " OpenSpecimen Diagnostic Report"
echo " $(date)"
echo "============================================"
echo ""

# 1. Estado de contenedores
echo -e "${BLUE}[1] Estado de contenedores:${NC}"
docker compose ps
echo ""

# 2. Verificar MySQL
echo -e "${BLUE}[2] Configuración de MySQL:${NC}"
if docker exec openspecimen-mysql mysqladmin ping -h localhost -u openspecimen -psgs2026 2>/dev/null; then
    echo -e "${GREEN}MySQL está respondiendo${NC}"
    
    echo ""
    echo "Variables críticas:"
    docker exec openspecimen-mysql mysql -u root -prootpass -N -e "
        SHOW VARIABLES LIKE 'lower_case_table_names';
        SHOW VARIABLES LIKE 'log_bin_trust_function_creators';
        SHOW VARIABLES LIKE 'character_set_server';
        SHOW VARIABLES LIKE 'collation_server';
    " 2>/dev/null | while read var val; do
        echo "  $var = $val"
    done
    
    echo ""
    echo "Estado de Liquibase (DATABASECHANGELOG):"
    count=$(docker exec openspecimen-mysql mysql -u openspecimen -psgs2026 openspecimen -N -e "SELECT COUNT(*) FROM DATABASECHANGELOG;" 2>/dev/null)
    if [ -n "$count" ] && [ "$count" != "0" ]; then
        echo -e "  ${GREEN}$count changesets ejecutados${NC}"
        echo "  Últimos 5 changesets:"
        docker exec openspecimen-mysql mysql -u openspecimen -psgs2026 openspecimen -e "
            SELECT ID, EXECTYPE, DATE_FORMAT(DATEEXECUTED, '%Y-%m-%d %H:%i') as FECHA 
            FROM DATABASECHANGELOG 
            ORDER BY DATEEXECUTED DESC LIMIT 5;
        " 2>/dev/null
    else
        echo -e "  ${YELLOW}DATABASECHANGELOG vacía o no existe${NC}"
    fi
else
    echo -e "${RED}MySQL no está respondiendo${NC}"
fi
echo ""

# 3. Verificar OpenSpecimen
echo -e "${BLUE}[3] Estado de OpenSpecimen:${NC}"
if docker ps | grep -q openspecimen-app; then
    echo "Contenedor activo: Sí"
    
    # Verificar si responde HTTP
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/openspecimen/ | grep -q "200\|302"; then
        echo -e "${GREEN}HTTP respondiendo correctamente${NC}"
    else
        echo -e "${YELLOW}HTTP no responde (puede estar iniciando)${NC}"
    fi
    
    # Verificar context.xml montado
    echo ""
    echo "Verificando context.xml montado:"
    if docker exec openspecimen-app test -f /usr/local/tomcat/conf/Catalina/localhost/openspecimen.xml; then
        echo -e "  ${GREEN}openspecimen.xml presente${NC}"
        echo "  Contenido del Resource JNDI:"
        docker exec openspecimen-app grep -A5 "Resource" /usr/local/tomcat/conf/Catalina/localhost/openspecimen.xml 2>/dev/null | head -10
    else
        echo -e "  ${RED}openspecimen.xml NO encontrado${NC}"
    fi
    
    # Verificar openspecimen.properties
    echo ""
    echo "Verificando openspecimen.properties:"
    if docker exec openspecimen-app test -f /usr/local/tomcat/conf/openspecimen.properties; then
        echo -e "  ${GREEN}openspecimen.properties presente${NC}"
        echo "  Configuración de datasource:"
        docker exec openspecimen-app grep "datasource" /usr/local/tomcat/conf/openspecimen.properties 2>/dev/null
    else
        echo -e "  ${RED}openspecimen.properties NO encontrado${NC}"
    fi
else
    echo -e "${RED}Contenedor no está corriendo${NC}"
fi
echo ""

# 4. Errores recientes
echo -e "${BLUE}[4] Errores recientes en logs:${NC}"
LOG_FILE="volumes/tomcat_logs/localhost.$(date +%Y-%m-%d).log"
if [ -f "$LOG_FILE" ]; then
    echo "Archivo: $LOG_FILE"
    echo ""
    grep -E "SEVERE|ERROR|Exception|Caused by" "$LOG_FILE" 2>/dev/null | tail -20
else
    echo "No se encontró archivo de log para hoy"
    echo "Probando con docker logs:"
    docker compose logs openspecimen 2>&1 | grep -E "SEVERE|ERROR|Caused by" | tail -10
fi
echo ""

# 5. Conectividad de red
echo -e "${BLUE}[5] Conectividad de red (app -> mysql):${NC}"
if docker exec openspecimen-app bash -c "nc -zv mysql 3306" 2>&1 | grep -q "succeeded\|open"; then
    echo -e "${GREEN}Conexión a MySQL exitosa${NC}"
else
    echo -e "${RED}No se puede conectar a MySQL desde la app${NC}"
fi
echo ""

# 6. Recomendaciones
echo -e "${BLUE}[6] Recomendaciones:${NC}"
echo ""

# Verificar problemas comunes
if ! docker exec openspecimen-app test -f /usr/local/tomcat/conf/Catalina/localhost/openspecimen.xml 2>/dev/null; then
    echo -e "${RED}CRÍTICO: Falta el descriptor de contexto JNDI${NC}"
    echo "  Solución: Verificar que config/openspecimen.xml existe y está montado"
    echo ""
fi

lower=$(docker exec openspecimen-mysql mysql -u root -prootpass -N -e "SHOW VARIABLES LIKE 'lower_case_table_names';" 2>/dev/null | awk '{print $2}')
if [ "$lower" != "1" ]; then
    echo -e "${RED}CRÍTICO: lower_case_table_names != 1${NC}"
    echo "  Solución: Limpiar volumes/mysql_data y reiniciar"
    echo ""
fi

echo "============================================"
echo " Fin del diagnóstico"
echo "============================================"