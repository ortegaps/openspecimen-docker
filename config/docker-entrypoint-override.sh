#!/bin/bash
# Inyectar context.xml con JNDI Resource
cat > /usr/local/tomcat/conf/context.xml << 'CTXEOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context>
    <WatchedResource>WEB-INF/web.xml</WatchedResource>
    <WatchedResource>${catalina.base}/conf/web.xml</WatchedResource>
    <Resource name="jdbc/openspecimen"
              auth="Container"
              type="javax.sql.DataSource"
              driverClassName="com.mysql.jdbc.Driver"
              url="jdbc:mysql://openspecimen-mysql:3306/openspecimen?useSSL=false&allowPublicKeyRetrieval=true"
              username="openspecimen"
              password="sgs2026"
              maxActive="100"
              maxIdle="30"
              maxWait="10000"
              testOnBorrow="true"
              validationQuery="select 1 from dual"/>
    <Environment
              name="config/openspecimen"
              value="/usr/local/tomcat/conf/openspecimen.properties"
              type="java.lang.String"/>
</Context>
CTXEOF

mkdir -p /usr/local/tomcat/conf/Catalina/localhost
cp /usr/local/tomcat/conf/context.xml /usr/local/tomcat/conf/Catalina/localhost/openspecimen.xml

exec catalina.sh run
