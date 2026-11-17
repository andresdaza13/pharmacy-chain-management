#!/bin/bash
# Se ejecuta UNA sola vez, cuando el contenedor de Oracle crea la base por primera vez.
# 1) Le da DBA al usuario farmacia (04_roles.sql crea roles y usuarios).
# 2) Ejecuta, en orden alfabético, todos los .sql de FarmaciaSpring/scripts como farmacia.
set -e
echo ">> Dando DBA a farmacia"
sqlplus -s "sys/${ORACLE_PASSWORD}@//localhost/FREEPDB1 as sysdba" <<SQL
GRANT DBA TO farmacia;
EXIT;
SQL

for f in $(ls /scripts/*.sql | sort); do
  echo ">> Ejecutando $f"
  sqlplus -s "farmacia/${APP_USER_PASSWORD}@//localhost/FREEPDB1" <<SQL
SET DEFINE OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE
@${f}
EXIT;
SQL
done
echo ">> Esquema de la farmacia listo"
