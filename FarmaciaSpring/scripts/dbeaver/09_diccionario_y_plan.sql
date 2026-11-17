-- =====================================================================
-- 09_diccionario_y_plan.sql   (evidencias para el informe: puntos I.5 y I.6)
-- COMO USARLO EN DBEAVER: pon el cursor dentro de UNA consulta y pulsa Ctrl+Enter.
-- Toma pantallazo de cada resultado para el informe.
-- =====================================================================

-- ===================== A. DICCIONARIO DE DATOS =====================
-- El diccionario de datos son vistas de Oracle que describen TU esquema.
-- USER_* = objetos de tu usuario | ALL_* = a los que tienes acceso | DBA_* = toda la base

-- A1. Tablas, numero de filas y ultima vez que se calcularon estadisticas
SELECT table_name, num_rows, last_analyzed
  FROM user_tables
 ORDER BY table_name;

-- A2. Columnas de cada tabla con su tipo y si aceptan nulos
SELECT table_name, column_id, column_name, data_type, data_length, nullable, data_default
  FROM user_tab_columns
 WHERE table_name IN ('PERSONA','CLIENTE','EMPLEADO','VENTA','VENTA_LOTE','LOTE','MEDICAMENTO')
 ORDER BY table_name, column_id;

-- A3. Restricciones (P = llave primaria, R = foranea, U = unica, C = check)
SELECT table_name, constraint_name, constraint_type, search_condition_vc AS regla, r_constraint_name, status
  FROM user_constraints
 WHERE constraint_type IN ('P', 'R', 'U', 'C')
   AND NVL(search_condition_vc, 'x') NOT LIKE '%IS NOT NULL'
 ORDER BY table_name, constraint_type;

-- A4. Secuencias y su valor actual
SELECT sequence_name, min_value, increment_by, last_number
  FROM user_sequences
 ORDER BY sequence_name;

-- A5. Columnas IDENTITY (Oracle genera el valor)
SELECT table_name, column_name, generation_type FROM user_tab_identity_cols;

-- A6. Disparadores: tipo (BEFORE/AFTER/INSTEAD OF/COMPOUND), evento y tabla
SELECT trigger_name, trigger_type, triggering_event, table_name, status
  FROM user_triggers
 ORDER BY table_name, trigger_name;

-- A7. Paquetes, funciones, vistas: todo debe estar VALID
SELECT object_type, object_name, status, last_ddl_time
  FROM user_objects
 WHERE object_type IN ('PACKAGE', 'PACKAGE BODY', 'FUNCTION', 'PROCEDURE', 'TRIGGER', 'VIEW', 'SEQUENCE', 'INDEX')
 ORDER BY object_type, object_name;

-- A8. Procedimientos y funciones de cada paquete
SELECT object_name AS paquete, procedure_name AS subprograma
  FROM user_procedures
 WHERE object_type = 'PACKAGE' AND procedure_name IS NOT NULL
 ORDER BY object_name, procedure_name;

-- A9. Parametros de un subprograma (ejemplo: registrar_venta del equipo)
SELECT position, argument_name, in_out, data_type
  FROM user_arguments
 WHERE package_name = 'PKG_VENTAS' AND object_name = 'REGISTRAR_VENTA'
 ORDER BY position;

-- A10. Codigo fuente guardado en el diccionario
SELECT line, text FROM user_source WHERE name = 'PKG_TRASLADOS' AND type = 'PACKAGE BODY' ORDER BY line;

-- A11. Dependencias: que objetos usa pkg_ventas
SELECT name, type, referenced_name, referenced_type
  FROM user_dependencies
 WHERE name = 'PKG_VENTAS'
 ORDER BY referenced_type, referenced_name;

-- A12. Roles y privilegios que se otorgaron (04_roles.sql)
SELECT grantee, table_name, privilege FROM user_tab_privs_made ORDER BY grantee, table_name;

-- ===================== B. INDICES =====================
-- B1. Indices y sus columnas
SELECT i.index_name, i.index_type, i.uniqueness, c.column_name, c.column_position
  FROM user_indexes i
  JOIN user_ind_columns c ON c.index_name = i.index_name
 WHERE i.table_name IN ('LOTE', 'VENTA', 'PERSONA')
 ORDER BY i.index_name, c.column_position;

-- B2. Expresion de los indices BASADOS EN FUNCION
SELECT index_name, table_name, column_expression
  FROM user_ind_expressions;

-- ===================== C. PLAN DE EJECUCION =====================
-- EXPLAIN PLAN guarda el plan en PLAN_TABLE; DBMS_XPLAN.DISPLAY lo muestra.
-- Ejecuta las dos sentencias de cada ejemplo, una tras otra.
-- (En DBeaver tambien puedes seleccionar la consulta y pulsar Ctrl+Shift+E)

-- C1. Indice basado en funcion idx_venta_dia: debe aparecer "INDEX RANGE SCAN | IDX_VENTA_DIA"
EXPLAIN PLAN SET STATEMENT_ID = 'ventas_dia' FOR
SELECT id_venta, total FROM Venta WHERE TRUNC(fecha_venta) = TRUNC(SYSDATE);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'ventas_dia', 'TYPICAL'));

-- C2. Indice basico compuesto idx_lote_med_suc_venc (lo usa el FEFO)
EXPLAIN PLAN SET STATEMENT_ID = 'fefo' FOR
SELECT id_lote, cantidad_actual FROM Lote
 WHERE id_medicamento = 1 AND id_sucursal = 1 AND fecha_vencimiento > TRUNC(SYSDATE)
 ORDER BY fecha_vencimiento;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'fefo', 'TYPICAL'));

-- C3. Indice basado en funcion UPPER(apellido)
EXPLAIN PLAN SET STATEMENT_ID = 'apellido' FOR
SELECT id_persona, nombre, apellido FROM Persona WHERE UPPER(apellido) = 'GOMEZ';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'apellido', 'TYPICAL'));

-- C4. Comparacion: sin la funcion el indice NO se usa (sale TABLE ACCESS FULL)
EXPLAIN PLAN SET STATEMENT_ID = 'sin_indice' FOR
SELECT id_persona, nombre, apellido FROM Persona WHERE apellido LIKE '%mez';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'sin_indice', 'TYPICAL'));

-- ===================== D. MONITOREO DE USO DE INDICES =====================
-- D1. Ejecuta primero las consultas de C (sin EXPLAIN) para que los indices se usen de verdad:
SELECT id_venta, total FROM Venta WHERE TRUNC(fecha_venta) = TRUNC(SYSDATE);

SELECT id_persona, nombre FROM Persona WHERE UPPER(apellido) = 'GOMEZ';

-- D2. USED = YES indica que Oracle uso el indice desde que se activo MONITORING USAGE
SELECT index_name, table_name, monitoring, used, start_monitoring
  FROM user_object_usage
 ORDER BY index_name;

-- D3. (Oracle 12.2+) Estadisticas detalladas de uso. Se actualizan cada ~15 minutos.
SELECT name, total_access_count, total_exec_count, last_used
  FROM dba_index_usage
 WHERE owner = USER
 ORDER BY name;
