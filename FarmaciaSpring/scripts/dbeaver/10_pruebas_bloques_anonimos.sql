-- =====================================================================
-- 10_pruebas_bloques_anonimos.sql  (punto II.4 del documento)
-- COMO USARLO EN DBEAVER:
--   1. Activa la salida de DBMS_OUTPUT: boton "Show server output" a la izquierda del editor
--      (o Ctrl+Shift+O). Aparece la pestana "Output".
--   2. Selecciona con el mouse UN bloque completo (desde DECLARE/BEGIN hasta su END;)
--      y pulsa Ctrl+Enter.
--   3. Toma pantallazo del resultado en "Output" para el informe.
-- Los bloques que modifican datos terminan en ROLLBACK, para poder repetirlos.
-- =====================================================================


-- PRUEBA 1. FUNCIONES de 06 (fn_estado_lote, fn_dias_para_vencer, fn_stock_medicamento)
BEGIN
  FOR l IN (SELECT id_lote, id_medicamento, id_sucursal FROM Lote ORDER BY id_lote) LOOP
    DBMS_OUTPUT.PUT_LINE('Lote ' || l.id_lote || ': ' || fn_estado_lote(l.id_lote)
      || ' (' || fn_dias_para_vencer(l.id_lote) || ' dias) | stock del medicamento en la sucursal: '
      || fn_stock_medicamento(l.id_medicamento, l.id_sucursal));
  END LOOP;
END;


-- PRUEBA 2. COLECCION PUBLICA del paquete (pkg_reportes.g_resumen) + BULK COLLECT
BEGIN
  pkg_reportes.cargar_resumen_sucursales(TRUNC(SYSDATE) - 30, TRUNC(SYSDATE));
  DBMS_OUTPUT.PUT_LINE('Filas en la coleccion publica: ' || pkg_reportes.g_resumen.COUNT);
  pkg_reportes.imprimir_resumen;
END;


-- PRUEBA 3. FUNCIONES simples y parametrizadas de pkg_reportes
BEGIN
  DBMS_OUTPUT.PUT_LINE('Ventas de hoy: ' || pkg_reportes.fn_ventas_hoy);
  DBMS_OUTPUT.PUT_LINE('Total vendido ultimos 30 dias: '
    || pkg_reportes.fn_total_vendido(SYSDATE - 30, SYSDATE));
END;


-- PRUEBA 4. EXCEPCION propia: rango de fechas al reves -> ORA-20060
BEGIN
  DBMS_OUTPUT.PUT_LINE(pkg_reportes.fn_total_vendido(SYSDATE, SYSDATE - 30));
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error capturado: ' || SQLCODE || ' -> ' || SQLERRM);
END;


-- PRUEBA 5. Coleccion de %ROWTYPE devuelta por una funcion + ARREGLO ASOCIATIVO
DECLARE
  v_lotes pkg_reportes.t_lotes;
  v_stock pkg_reportes.t_stock;
  v_id    PLS_INTEGER;
  v_med   NUMBER;
  v_suc   NUMBER;
BEGIN
  SELECT MIN(id_medicamento), MIN(id_sucursal) INTO v_med, v_suc FROM Lote;
  v_lotes := pkg_reportes.fn_lotes_de_medicamento(v_med);
  FOR i IN 1 .. v_lotes.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE('Lote ' || v_lotes(i).id_lote || ' vence ' || TO_CHAR(v_lotes(i).fecha_vencimiento, 'DD/MM/YYYY')
      || ' quedan ' || v_lotes(i).cantidad_actual);
  END LOOP;

  v_stock := pkg_reportes.fn_stock_sucursal(v_suc);
  v_id := v_stock.FIRST;                          -- recorrido de un arreglo asociativo
  WHILE v_id IS NOT NULL LOOP
    DBMS_OUTPUT.PUT_LINE('Medicamento ' || v_id || ': ' || v_stock(v_id) || ' unidades');
    v_id := v_stock.NEXT(v_id);
  END LOOP;
END;


-- PRUEBA 6. CURSOR SIMPLE y CURSOR PARAMETRIZADO
DECLARE
  v_suc NUMBER;
BEGIN
  SELECT MIN(id_sucursal) INTO v_suc FROM Sucursal;
  pkg_reportes.listar_medicamentos_agotados;
  pkg_reportes.listar_lotes_por_vencer(p_id_sucursal => v_suc, p_dias => 30);
END;


-- PRUEBA 7. VENTA COMPLETA con los paquetes del equipo + triggers (FEFO) y ROLLBACK
DECLARE
  v_cli   NUMBER;
  v_emp   NUMBER;
  v_suc   NUMBER;
  v_med   NUMBER;
  v_venta NUMBER;
  v_cod   Venta.codigo_factura%TYPE;
  v_total Venta.total%TYPE;
BEGIN
  SELECT MIN(id_cliente) INTO v_cli FROM Cliente;
  SELECT id_empleado, id_sucursal INTO v_emp, v_suc FROM Empleado WHERE cargo = 'VENDEDOR' AND ROWNUM = 1;
  SELECT l.id_medicamento INTO v_med
    FROM Lote l JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
   WHERE l.id_sucursal = v_suc AND l.cantidad_actual >= 2 AND l.fecha_vencimiento > TRUNC(SYSDATE) + 1
     AND m.requiere_receta = 'N' AND ROWNUM = 1;

  pkg_ventas.registrar_venta(p_id_cliente => v_cli, p_id_empleado => v_emp, p_id_sucursal => v_suc,
                             p_metodo_pago => 'EFECTIVO', p_id_venta => v_venta);
  pkg_ventas.agregar_medicamento(v_venta, v_med, 2);

  SELECT codigo_factura, total INTO v_cod, v_total FROM Venta WHERE id_venta = v_venta;
  DBMS_OUTPUT.PUT_LINE('Venta ' || v_venta || ' factura ' || v_cod || ' total ' || v_total
    || ' | fn_total_venta: ' || pkg_ventas.fn_total_venta(v_venta));
  ROLLBACK;                                       -- prueba: no se guarda
  DBMS_OUTPUT.PUT_LINE('ROLLBACK: la venta y el descuento de stock se deshicieron.');
END;


-- PRUEBA 8. TRIGGER que bloquea: vender un medicamento CON receta sin datos del medico -> ORA-20016
DECLARE
  v_cli NUMBER; v_emp NUMBER; v_suc NUMBER; v_med NUMBER; v_venta NUMBER;
BEGIN
  SELECT MIN(id_cliente) INTO v_cli FROM Cliente;
  SELECT id_empleado, id_sucursal INTO v_emp, v_suc FROM Empleado WHERE cargo = 'REGENTE' AND ROWNUM = 1;
  SELECT MIN(id_medicamento) INTO v_med FROM Medicamento WHERE requiere_receta = 'S';
  pkg_ventas.registrar_venta(p_id_cliente => v_cli, p_id_empleado => v_emp, p_id_sucursal => v_suc,
                             p_metodo_pago => 'EFECTIVO', p_id_venta => v_venta);
  pkg_ventas.agregar_medicamento(v_venta, v_med, 1);
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('Bloqueado por trigger: ' || SQLERRM);
END;


-- PRUEBA 9. TRIGGER COMPUESTO: cambio de precio valido (se audita) e invalido (> 50 %)
DECLARE
  v_med NUMBER; v_precio NUMBER;
BEGIN
  SELECT MIN(id_medicamento) INTO v_med FROM Medicamento;
  SELECT precio_unitario INTO v_precio FROM Medicamento WHERE id_medicamento = v_med;

  UPDATE Medicamento SET precio_unitario = v_precio * 1.10 WHERE id_medicamento = v_med;    -- +10 %: OK
  FOR a IN (SELECT * FROM Auditoria_Precio WHERE id_medicamento = v_med ORDER BY id_auditoria DESC
            FETCH FIRST 1 ROW ONLY) LOOP
    DBMS_OUTPUT.PUT_LINE('Auditado: ' || a.precio_anterior || ' -> ' || a.precio_nuevo || ' por ' || a.usuario);
  END LOOP;

  BEGIN
    UPDATE Medicamento SET precio_unitario = v_precio * 3 WHERE id_medicamento = v_med;     -- x3: bloqueado
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Bloqueado por el trigger compuesto: ' || SQLERRM);
  END;
  ROLLBACK;
END;


-- PRUEBA 10. INSTEAD OF: registrar un PACIENTE insertando en la VISTA
DECLARE
  v_id NUMBER;
BEGIN
  INSERT INTO vw_pacientes (nombre, apellido, documento, email, direccion, telefono)
  VALUES ('Paciente', 'De Prueba', 'TEST-' || TO_CHAR(SYSDATE, 'HH24MISS'), 'prueba@correo.co', 'Calle 1', '3000000000');

  SELECT MAX(id_paciente) INTO v_id FROM vw_pacientes WHERE apellido = 'De Prueba';
  DBMS_OUTPUT.PUT_LINE('Paciente creado por el trigger INSTEAD OF con id ' || v_id);

  UPDATE vw_pacientes SET telefono = '3111111111' WHERE id_paciente = v_id;
  FOR p IN (SELECT * FROM vw_pacientes WHERE id_paciente = v_id) LOOP
    DBMS_OUTPUT.PUT_LINE('Telefono actualizado: ' || p.telefono);
  END LOOP;
  ROLLBACK;
END;


-- PRUEBA 11. TRANSACCION EXPLICITA: traslado que FALLA (cantidad exagerada) -> ROLLBACK TO SAVEPOINT
DECLARE
  v_lote NUMBER; v_antes NUMBER; v_despues NUMBER; v_destino NUMBER; v_emp NUMBER; v_nuevo NUMBER;
BEGIN
  SELECT id_lote, cantidad_actual INTO v_lote, v_antes FROM Lote
   WHERE cantidad_actual > 0 AND fecha_vencimiento > TRUNC(SYSDATE) AND ROWNUM = 1;
  SELECT e.id_empleado, e.id_sucursal INTO v_emp, v_destino
    FROM Empleado e WHERE e.id_sucursal != (SELECT id_sucursal FROM Lote WHERE id_lote = v_lote) AND ROWNUM = 1;
  BEGIN
    pkg_traslados.trasladar_stock(v_lote, v_destino, 999999, v_emp, v_nuevo);
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Traslado rechazado: ' || SQLERRM);
  END;
  SELECT cantidad_actual INTO v_despues FROM Lote WHERE id_lote = v_lote;
  DBMS_OUTPUT.PUT_LINE('Stock antes: ' || v_antes || ' / despues: ' || v_despues || ' (no cambio)');
END;


-- PRUEBA 12. TRANSACCION EXPLICITA: traslado EXITOSO de 2 unidades (hace COMMIT: SI queda guardado)
DECLARE
  v_lote NUMBER; v_destino NUMBER; v_emp NUMBER; v_nuevo NUMBER;
BEGIN
  SELECT id_lote INTO v_lote FROM Lote
   WHERE cantidad_actual >= 2 AND fecha_vencimiento > TRUNC(SYSDATE) AND ROWNUM = 1;
  SELECT e.id_empleado, e.id_sucursal INTO v_emp, v_destino
    FROM Empleado e WHERE e.id_sucursal != (SELECT id_sucursal FROM Lote WHERE id_lote = v_lote) AND ROWNUM = 1;
  pkg_traslados.trasladar_stock(v_lote, v_destino, 2, v_emp, v_nuevo);
  DBMS_OUTPUT.PUT_LINE('Trasladadas 2 unidades del lote ' || v_lote || ' al lote nuevo ' || v_nuevo
    || ' en la sucursal ' || v_destino);
END;


-- PRUEBA 13. SECUENCIA + TRIGGER de codigo: el id lo pone trg_*_id y el codigo de factura trg_venta_codigo
SELECT id_venta, codigo_factura, estado, total FROM Venta ORDER BY id_venta;

-- PRUEBA 14. Coleccion usada en SQL (funcion PIPELINED)
SELECT * FROM TABLE(pkg_reportes.fn_resumen_sucursales(TRUNC(SYSDATE) - 30, TRUNC(SYSDATE)));
