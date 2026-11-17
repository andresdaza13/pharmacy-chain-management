-- =====================================================================
-- 06_logica_negocio.sql  (adaptado al esquema REAL de FARMACIA_APP)
-- EJECUTAR COMO: farmacia_app, despues de 03, 04 y 05.
-- En DBeaver usa la version dbeaver/06_logica_negocio_DBEAVER.sql
--
-- COMO ENCAJA CON LO QUE YA TENIA EL EQUIPO
--   Requisito del documento        Donde esta
--   ---------------------------    ---------------------------------------------------------
--   registrar_persona              pkg_personas.registrar_persona               (equipo)
--   exclusividad Cliente/Empleado  FK compuesta (id, tipo_persona) + CHECK 'C'/'E'  (equipo)
--   registrar_venta (FEFO)         pkg_ventas.registrar_venta + agregar_medicamento (equipo)
--   validar venta/stock/receta     trg_venta_bi, trg_venta_lote_bi              (equipo)
--   descontar stock y total        trg_venta_lote_ai                            (equipo)
--   detalle inmutable              trg_venta_lote_inmutable                     (equipo)
--   anular_venta                   pkg_ventas.anular_venta                      (equipo)
--   fn_total_venta                 pkg_ventas.fn_total_venta                    (equipo)
--   registrar_lote                 pkg_inventario.registrar_lote                (03_paquetes.sql)
--   fn_dias_para_vencer            ESTE SCRIPT
--   fn_estado_lote                 ESTE SCRIPT
--   fn_stock_medicamento           ESTE SCRIPT
--   venta anulada no se reactiva   ESTE SCRIPT (trg_venta_estado_bu)
--   auditoria de precios           ESTE SCRIPT (trg_medicamento_auditoria)
--   5 reportes                     ESTE SCRIPT (vistas vw_rep_*)
--
-- Regla de vencimiento (igual que trg_venta_lote_bi del equipo):
--   un lote que vence HOY ya no se vende  ->  dias <= 0 es VENCIDO.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. FUNCIONES
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_dias_para_vencer(p_id_lote NUMBER) RETURN NUMBER IS
  v_vence DATE;
BEGIN
  SELECT fecha_vencimiento INTO v_vence FROM Lote WHERE id_lote = p_id_lote;
  RETURN TRUNC(v_vence) - TRUNC(SYSDATE);
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN NULL;
END fn_dias_para_vencer;
/

-- Estado DINAMICO: no se guarda, se calcula cada vez (dominio dinamico del documento)
CREATE OR REPLACE FUNCTION fn_estado_lote(p_id_lote NUMBER) RETURN VARCHAR2 IS
  c_umbral CONSTANT PLS_INTEGER := 30;          -- 30 dias o menos = proximo a vencer
  v_dias   NUMBER := fn_dias_para_vencer(p_id_lote);
BEGIN
  IF v_dias IS NULL THEN RETURN NULL;
  ELSIF v_dias <= 0 THEN RETURN 'VENCIDO';
  ELSIF v_dias <= c_umbral THEN RETURN 'PROXIMO_A_VENCER';
  ELSE RETURN 'VIGENTE';
  END IF;
END fn_estado_lote;
/

-- Stock vendible = suma de lotes que aun no vencen
CREATE OR REPLACE FUNCTION fn_stock_medicamento(p_id_medicamento NUMBER, p_id_sucursal NUMBER)
RETURN NUMBER IS
  v_total NUMBER;
BEGIN
  SELECT NVL(SUM(cantidad_actual), 0) INTO v_total
    FROM Lote
   WHERE id_medicamento = p_id_medicamento
     AND id_sucursal    = p_id_sucursal
     AND fecha_vencimiento > TRUNC(SYSDATE);
  RETURN v_total;
END fn_stock_medicamento;
/

-- ---------------------------------------------------------------------
-- 2. DISPARADORES NUEVOS (no se repite nada de lo que ya hacen los del equipo)
-- ---------------------------------------------------------------------
-- 2.1 Una venta ANULADA no vuelve a ACTIVA: si se pudiera, el stock ya devuelto
--     por anular_venta quedaria descuadrado.
CREATE OR REPLACE TRIGGER trg_venta_estado_bu
BEFORE UPDATE OF estado ON Venta
FOR EACH ROW
BEGIN
  IF :OLD.estado = 'ANULADA' AND :NEW.estado != 'ANULADA' THEN
    RAISE_APPLICATION_ERROR(-20030, 'Una venta anulada no se puede reactivar.');
  END IF;
END;
/

-- 2.2 Bitacora de cambios de precio
BEGIN
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
END;
/

CREATE OR REPLACE TRIGGER trg_medicamento_auditoria
AFTER UPDATE OF precio_unitario ON Medicamento
FOR EACH ROW
WHEN (NVL(OLD.precio_unitario, -1) != NVL(NEW.precio_unitario, -1))
BEGIN
  INSERT INTO Auditoria_Precio (id_medicamento, precio_anterior, precio_nuevo)
  VALUES (:NEW.id_medicamento, :OLD.precio_unitario, :NEW.precio_unitario);
END;
/

-- ---------------------------------------------------------------------
-- 3. VISTAS DE REPORTES (las ventas ANULADAS no cuentan como vendidas)
--    El valor de cada linea se calcula como cantidad * precio_unitario.
-- ---------------------------------------------------------------------
-- R1. Ventas por sucursal, empleado y fecha
CREATE OR REPLACE VIEW vw_rep_ventas AS
SELECT v.id_venta, v.fecha_venta, TRUNC(v.fecha_venta) AS dia,
       v.id_sucursal, s.nombre AS sucursal,
       v.id_empleado, pe.nombre || ' ' || pe.apellido AS empleado,
       v.metodo_pago, v.total
  FROM Venta v
  JOIN Sucursal s ON s.id_sucursal = v.id_sucursal
  JOIN Persona pe ON pe.id_persona = v.id_empleado
 WHERE v.estado = 'ACTIVA';

-- R2. Medicamentos mas vendidos por sucursal
CREATE OR REPLACE VIEW vw_rep_mas_vendidos AS
SELECT s.id_sucursal, s.nombre AS sucursal, m.id_medicamento, m.nombre_comercial AS medicamento,
       SUM(vl.cantidad) AS unidades, SUM(vl.cantidad * vl.precio_unitario) AS ingresos,
       RANK() OVER (PARTITION BY s.id_sucursal ORDER BY SUM(vl.cantidad) DESC) AS puesto
  FROM Venta_Lote vl
  JOIN Venta v       ON v.id_venta = vl.id_venta AND v.estado = 'ACTIVA'
  JOIN Lote l        ON l.id_lote = vl.id_lote
  JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
  JOIN Sucursal s    ON s.id_sucursal = v.id_sucursal
 GROUP BY s.id_sucursal, s.nombre, m.id_medicamento, m.nombre_comercial;

-- R3. Lotes vencidos o proximos a vencer
CREATE OR REPLACE VIEW vw_rep_lotes_alerta AS
SELECT s.id_sucursal, s.nombre AS sucursal, l.id_lote, m.nombre_comercial AS medicamento,
       l.cantidad_actual, l.fecha_vencimiento,
       fn_dias_para_vencer(l.id_lote) AS dias,
       fn_estado_lote(l.id_lote)      AS estado
  FROM Lote l
  JOIN Sucursal s    ON s.id_sucursal = l.id_sucursal
  JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
 WHERE fn_estado_lote(l.id_lote) IN ('VENCIDO', 'PROXIMO_A_VENCER');

-- R4. Ventas con receta (los datos del medico estan en la propia Venta)
CREATE OR REPLACE VIEW vw_rep_ventas_receta AS
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
 WHERE v.registro_medico IS NOT NULL;

-- R5. Lotes por proveedor y empleado responsable (la agregacion del MER)
CREATE OR REPLACE VIEW vw_rep_lotes_proveedor AS
SELECT l.id_lote, p.id_proveedor, p.nombre AS proveedor, p.nit,
       pe.nombre || ' ' || pe.apellido AS empleado, e.cargo,
       m.nombre_comercial AS medicamento, s.nombre AS sucursal,
       l.fecha_fabricacion, l.fecha_vencimiento, l.cantidad_inicial, l.cantidad_actual
  FROM Lote l
  JOIN Proveedor p   ON p.id_proveedor = l.id_proveedor
  JOIN Empleado e    ON e.id_empleado = l.id_empleado
  JOIN Persona pe    ON pe.id_persona = e.id_empleado
  JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
  JOIN Sucursal s    ON s.id_sucursal = l.id_sucursal;

-- ---------------------------------------------------------------------
-- 4. PERMISOS (tabla de usuarios y permisos del documento)
-- ---------------------------------------------------------------------
DECLARE
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
END;
/

-- ---------------------------------------------------------------------
-- 5. COMPROBACION: todo debe quedar VALID
-- ---------------------------------------------------------------------
SELECT object_type, object_name, status
  FROM user_objects
 WHERE object_type IN ('PACKAGE', 'PACKAGE BODY', 'FUNCTION', 'TRIGGER', 'VIEW')
 ORDER BY status, object_type, object_name;
