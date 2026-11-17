DECLARE
  -- =====================================================================
  -- 06_logica_negocio   (version para DBeaver, generada desde el script original)
  -- COMO EJECUTARLO EN DBEAVER:
  --   1. Verifica arriba que la conexion sea XEPDB1 / FARMACIA_APP.
  --   2. Ctrl+A (seleccionar TODO)  y luego  Ctrl+Enter.
  --   3. Si aparece una ventana pidiendo valores para :NEW / :OLD, pulsa "Ignore".
  --   4. Resultado:  SELECT * FROM instalacion_log ORDER BY id;
  -- POR QUE ASI: DBeaver no reconoce la "/" de SQL*Plus. Aqui todo es UN solo bloque PL/SQL
  -- y cada sentencia se ejecuta con EXECUTE IMMEDIATE (SQL dinamico).
  -- Se puede ejecutar varias veces: lo que "ya existe" se informa y se sigue.
  -- =====================================================================
  v_ok      PLS_INTEGER := 0;
  v_existia PLS_INTEGER := 0;
  v_error   PLS_INTEGER := 0;

  -- Guarda el resultado de cada paso en la tabla instalacion_log
  PROCEDURE anotar(p_paso NUMBER, p_estado VARCHAR2, p_detalle VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'INSERT INTO instalacion_log (script, paso, estado, detalle) VALUES (:1, :2, :3, :4)'
      USING '06_logica_negocio', p_paso, p_estado, SUBSTR(p_detalle, 1, 900);
    DBMS_OUTPUT.PUT_LINE(RPAD(p_estado, 10) || p_paso || '. ' || SUBSTR(p_detalle, 1, 200));
  END;

  PROCEDURE paso(p_n NUMBER, p_titulo VARCHAR2, p_sql CLOB) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    v_ok := v_ok + 1;
    anotar(p_n, 'OK', p_titulo);
  EXCEPTION WHEN OTHERS THEN
    -- -955 nombre en uso | -1430 columna existe | -1920 usuario existe | -1921 rol existe
    IF SQLCODE IN (-955, -1430, -1920, -1921, -1408) THEN
      v_existia := v_existia + 1;
      anotar(p_n, 'YA EXISTE', p_titulo);
    ELSIF SQLCODE IN (-4043, -4080) THEN    -- DROP de algo que no existe: no hay nada que borrar
      v_existia := v_existia + 1;
      anotar(p_n, 'NO EXISTE', p_titulo);
    ELSIF SQLCODE = -942 THEN     -- la tabla no existe en tu esquema: se omite ese permiso
      v_existia := v_existia + 1;
      anotar(p_n, 'OMITIDO', p_titulo || ' -> esa tabla no existe en tu esquema');
    ELSIF SQLCODE = -24344 THEN   -- se creo, pero con errores de compilacion
      v_error := v_error + 1;
      anotar(p_n, 'ERROR', p_titulo || ' -> compilado con errores: SELECT * FROM user_errors');
    ELSE
      v_error := v_error + 1;
      anotar(p_n, 'ERROR', p_titulo || ' -> ' || SQLERRM);
    END IF;
  END;
BEGIN
  DBMS_OUTPUT.ENABLE(NULL);
  BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE instalacion_log (id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      script VARCHAR2(60), paso NUMBER, estado VARCHAR2(12), detalle VARCHAR2(1000), fecha DATE DEFAULT SYSDATE)';
  EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF;
  END;

  paso(1, 'CREATE OR REPLACE FUNCTION fn_dias_para_vencer(p_id_lote NUMBER) RETURN NUMBER IS v_vence ', q'~CREATE OR REPLACE FUNCTION fn_dias_para_vencer(p_id_lote NUMBER) RETURN NUMBER IS
  v_vence DATE;
BEGIN
  SELECT fecha_vencimiento INTO v_vence FROM Lote WHERE id_lote = p_id_lote;
  RETURN TRUNC(v_vence) - TRUNC(SYSDATE);
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN NULL;
END fn_dias_para_vencer;~');
  paso(2, 'CREATE OR REPLACE FUNCTION fn_estado_lote(p_id_lote NUMBER) RETURN VARCHAR2 IS c_umbral CO', q'~CREATE OR REPLACE FUNCTION fn_estado_lote(p_id_lote NUMBER) RETURN VARCHAR2 IS
  c_umbral CONSTANT PLS_INTEGER := 30;          -- 30 dias o menos = proximo a vencer
  v_dias   NUMBER := fn_dias_para_vencer(p_id_lote);
BEGIN
  IF v_dias IS NULL THEN RETURN NULL;
  ELSIF v_dias <= 0 THEN RETURN 'VENCIDO';
  ELSIF v_dias <= c_umbral THEN RETURN 'PROXIMO_A_VENCER';
  ELSE RETURN 'VIGENTE';
  END IF;
END fn_estado_lote;~');
  paso(3, 'CREATE OR REPLACE FUNCTION fn_stock_medicamento(p_id_medicamento NUMBER, p_id_sucursal NUM', q'~CREATE OR REPLACE FUNCTION fn_stock_medicamento(p_id_medicamento NUMBER, p_id_sucursal NUMBER)
RETURN NUMBER IS
  v_total NUMBER;
BEGIN
  SELECT NVL(SUM(cantidad_actual), 0) INTO v_total
    FROM Lote
   WHERE id_medicamento = p_id_medicamento
     AND id_sucursal    = p_id_sucursal
     AND fecha_vencimiento > TRUNC(SYSDATE);
  RETURN v_total;
END fn_stock_medicamento;~');
  paso(4, 'CREATE OR REPLACE TRIGGER trg_venta_estado_bu BEFORE UPDATE OF estado ON Venta FOR EACH RO', q'~CREATE OR REPLACE TRIGGER trg_venta_estado_bu
BEFORE UPDATE OF estado ON Venta
FOR EACH ROW
BEGIN
  IF :OLD.estado = 'ANULADA' AND :NEW.estado != 'ANULADA' THEN
    RAISE_APPLICATION_ERROR(-20030, 'Una venta anulada no se puede reactivar.');
  END IF;
END;~');
  paso(5, 'BEGIN EXECUTE IMMEDIATE q''[ CREATE TABLE Auditoria_Precio ( id_auditoria NUMBER GENERATED ', q'~BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TABLE Auditoria_Precio (
      id_auditoria     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      id_medicamento   NUMBER        NOT NULL,
      precio_anterior  NUMBER(12,2),
      precio_nuevo     NUMBER(12,2),
      usuario          VARCHAR2(128) DEFAULT USER    NOT NULL,
      fecha            DATE          DEFAULT SYSDATE NOT NULL
    )]';
EXCEPTION WHEN OTHERS THEN
  IF SQLCODE != -955 THEN RAISE; END IF;
END;~');
  paso(6, 'CREATE OR REPLACE TRIGGER trg_medicamento_auditoria AFTER UPDATE OF precio_unitario ON Med', q'~CREATE OR REPLACE TRIGGER trg_medicamento_auditoria
AFTER UPDATE OF precio_unitario ON Medicamento
FOR EACH ROW
WHEN (NVL(OLD.precio_unitario, -1) != NVL(NEW.precio_unitario, -1))
BEGIN
  INSERT INTO Auditoria_Precio (id_medicamento, precio_anterior, precio_nuevo)
  VALUES (:NEW.id_medicamento, :OLD.precio_unitario, :NEW.precio_unitario);
END;~');
  paso(7, 'CREATE OR REPLACE VIEW vw_rep_ventas AS SELECT v.id_venta, v.fecha_venta, TRUNC(v.fecha_ve', q'~CREATE OR REPLACE VIEW vw_rep_ventas AS
SELECT v.id_venta, v.fecha_venta, TRUNC(v.fecha_venta) AS dia,
       v.id_sucursal, s.nombre AS sucursal,
       v.id_empleado, pe.nombre || ' ' || pe.apellido AS empleado,
       v.metodo_pago, v.total
  FROM Venta v
  JOIN Sucursal s ON s.id_sucursal = v.id_sucursal
  JOIN Persona pe ON pe.id_persona = v.id_empleado
 WHERE v.estado = 'ACTIVA'~');
  paso(8, 'CREATE OR REPLACE VIEW vw_rep_mas_vendidos AS SELECT s.id_sucursal, s.nombre AS sucursal, ', q'~CREATE OR REPLACE VIEW vw_rep_mas_vendidos AS
SELECT s.id_sucursal, s.nombre AS sucursal, m.id_medicamento, m.nombre_comercial AS medicamento,
       SUM(vl.cantidad) AS unidades, SUM(vl.cantidad * vl.precio_unitario) AS ingresos,
       RANK() OVER (PARTITION BY s.id_sucursal ORDER BY SUM(vl.cantidad) DESC) AS puesto
  FROM Venta_Lote vl
  JOIN Venta v       ON v.id_venta = vl.id_venta AND v.estado = 'ACTIVA'
  JOIN Lote l        ON l.id_lote = vl.id_lote
  JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
  JOIN Sucursal s    ON s.id_sucursal = v.id_sucursal
 GROUP BY s.id_sucursal, s.nombre, m.id_medicamento, m.nombre_comercial~');
  paso(9, 'CREATE OR REPLACE VIEW vw_rep_lotes_alerta AS SELECT s.id_sucursal, s.nombre AS sucursal, ', q'~CREATE OR REPLACE VIEW vw_rep_lotes_alerta AS
SELECT s.id_sucursal, s.nombre AS sucursal, l.id_lote, m.nombre_comercial AS medicamento,
       l.cantidad_actual, l.fecha_vencimiento,
       fn_dias_para_vencer(l.id_lote) AS dias,
       fn_estado_lote(l.id_lote)      AS estado
  FROM Lote l
  JOIN Sucursal s    ON s.id_sucursal = l.id_sucursal
  JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
 WHERE fn_estado_lote(l.id_lote) IN ('VENCIDO', 'PROXIMO_A_VENCER')~');
  paso(10, 'CREATE OR REPLACE VIEW vw_rep_ventas_receta AS SELECT v.id_venta, v.fecha_venta, v.estado,', q'~CREATE OR REPLACE VIEW vw_rep_ventas_receta AS
SELECT v.id_venta, v.fecha_venta, v.estado, s.nombre AS sucursal,
       pc.nombre || ' ' || pc.apellido AS cliente,
       v.nombre_medico, v.registro_medico, v.total,
       (SELECT LISTAGG(DISTINCT m.nombre_comercial, ', ') WITHIN GROUP (ORDER BY m.nombre_comercial)
          FROM Venta_Lote vl JOIN Lote l ON l.id_lote = vl.id_lote
          JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
         WHERE vl.id_venta = v.id_venta AND m.requiere_receta = 'S') AS medicamentos
  FROM Venta v
  JOIN Sucursal s ON s.id_sucursal = v.id_sucursal
  JOIN Persona pc ON pc.id_persona = v.id_cliente
 WHERE v.registro_medico IS NOT NULL~');
  paso(11, 'CREATE OR REPLACE VIEW vw_rep_lotes_proveedor AS SELECT l.id_lote, p.id_proveedor, p.nombr', q'~CREATE OR REPLACE VIEW vw_rep_lotes_proveedor AS
SELECT l.id_lote, p.id_proveedor, p.nombre AS proveedor, p.nit,
       pe.nombre || ' ' || pe.apellido AS empleado, e.cargo,
       m.nombre_comercial AS medicamento, s.nombre AS sucursal,
       l.fecha_fabricacion, l.fecha_vencimiento, l.cantidad_inicial, l.cantidad_actual
  FROM Lote l
  JOIN Proveedor p   ON p.id_proveedor = l.id_proveedor
  JOIN Empleado e    ON e.id_empleado = l.id_empleado
  JOIN Persona pe    ON pe.id_persona = e.id_empleado
  JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
  JOIN Sucursal s    ON s.id_sucursal = l.id_sucursal~');
  paso(12, 'DECLARE PROCEDURE dar(p_sql VARCHAR2) IS BEGIN EXECUTE IMMEDIATE p_sql; EXCEPTION WHEN OTH', q'~DECLARE
  PROCEDURE dar(p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE NOT IN (-1917, -1919, -942, -4042) THEN RAISE; END IF;  -- rol u objeto no existe
  END;
BEGIN
  -- admin_farmacia: todo
  FOR o IN (SELECT column_value n FROM TABLE(sys.odcivarchar2list(
              'PKG_PERSONAS','PKG_VENTAS','PKG_INVENTARIO','PKG_MANTENIMIENTO',
              'FN_DIAS_PARA_VENCER','FN_ESTADO_LOTE','FN_STOCK_MEDICAMENTO'))) LOOP
    dar('GRANT EXECUTE ON ' || o.n || ' TO admin_farmacia');
  END LOOP;

  -- vendedor: registrar_venta (pkg_ventas) y alta de clientes (pkg_personas)
  dar('GRANT EXECUTE ON pkg_ventas TO vendedor');
  dar('GRANT EXECUTE ON pkg_personas TO vendedor');

  -- regente: todo lo del vendedor + registrar_lote + fn_estado_lote
  dar('GRANT EXECUTE ON pkg_ventas TO regente');
  dar('GRANT EXECUTE ON pkg_personas TO regente');
  dar('GRANT EXECUTE ON pkg_inventario TO regente');
  dar('GRANT EXECUTE ON fn_estado_lote TO regente');
  dar('GRANT EXECUTE ON fn_dias_para_vencer TO regente');

  -- administrador de sucursal: registrar_persona y registrar_lote
  dar('GRANT EXECUTE ON pkg_personas TO administrador_sucursal');
  dar('GRANT EXECUTE ON pkg_inventario TO administrador_sucursal');
  dar('GRANT EXECUTE ON pkg_mantenimiento TO administrador_sucursal');

  -- gerencia: funciones y vistas de reportes (solo lectura)
  FOR o IN (SELECT column_value n FROM TABLE(sys.odcivarchar2list(
              'FN_DIAS_PARA_VENCER','FN_ESTADO_LOTE','FN_STOCK_MEDICAMENTO'))) LOOP
    dar('GRANT EXECUTE ON ' || o.n || ' TO gerencia');
  END LOOP;
  FOR v IN (SELECT column_value n FROM TABLE(sys.odcivarchar2list(
              'VW_REP_VENTAS','VW_REP_MAS_VENDIDOS','VW_REP_LOTES_ALERTA',
              'VW_REP_VENTAS_RECETA','VW_REP_LOTES_PROVEEDOR','AUDITORIA_PRECIO'))) LOOP
    dar('GRANT SELECT ON ' || v.n || ' TO gerencia');
    dar('GRANT SELECT ON ' || v.n || ' TO auditor');
    dar('GRANT SELECT ON ' || v.n || ' TO admin_farmacia');
  END LOOP;
END;~');

  -- Resumen: objetos que hayan quedado invalidos
  FOR o IN (SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID' ORDER BY 1, 2) LOOP
    v_error := v_error + 1;
    anotar(0, 'INVALIDO', o.object_type || ' ' || o.object_name || ' (ver: SELECT * FROM user_errors)');
  END LOOP;
  anotar(0, 'RESUMEN', v_ok || ' ok, ' || v_existia || ' ya existian u omitidos, ' || v_error || ' con error');
  COMMIT;
END;
