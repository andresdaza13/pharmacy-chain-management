DECLARE
  -- =====================================================================
  -- 08_requisitos_proyecto   (version para DBeaver, generada desde el script original)
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
      USING '08_requisitos_proyecto', p_paso, p_estado, SUBSTR(p_detalle, 1, 900);
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

  paso(1, 'DECLARE TYPE r_tabla IS RECORD (tabla VARCHAR2(30), columna VARCHAR2(30)); -- REGISTRO TYP', q'~DECLARE
  TYPE r_tabla IS RECORD (tabla VARCHAR2(30), columna VARCHAR2(30));     -- REGISTRO
  TYPE t_tablas IS TABLE OF r_tabla;                                       -- COLECCION de registros
  v_tablas t_tablas := t_tablas();
  v_es_identity NUMBER;
  v_max   NUMBER;
  v_seq   VARCHAR2(30);
  v_trg   VARCHAR2(30);
  v_existe NUMBER;

  PROCEDURE agregar(p_tabla VARCHAR2, p_col VARCHAR2) IS
  BEGIN
    v_tablas.EXTEND;
    v_tablas(v_tablas.LAST).tabla   := p_tabla;
    v_tablas(v_tablas.LAST).columna := p_col;
  END;
BEGIN
  agregar('CIUDAD', 'ID_CIUDAD');
  agregar('SUCURSAL', 'ID_SUCURSAL');
  agregar('CATEGORIA', 'ID_CATEGORIA');
  agregar('MEDICAMENTO', 'ID_MEDICAMENTO');
  agregar('PROVEEDOR', 'ID_PROVEEDOR');
  agregar('LOTE', 'ID_LOTE');

  FOR i IN 1 .. v_tablas.COUNT LOOP
    SELECT COUNT(*) INTO v_es_identity
      FROM user_tab_identity_cols
     WHERE table_name = v_tablas(i).tabla AND column_name = v_tablas(i).columna;

    IF v_es_identity = 0 THEN
      v_seq := 'SEQ_' || v_tablas(i).tabla;
      v_trg := 'TRG_' || v_tablas(i).tabla || '_ID';
      EXECUTE IMMEDIATE 'SELECT NVL(MAX(' || v_tablas(i).columna || '), 0) + 1 FROM ' || v_tablas(i).tabla
        INTO v_max;

      SELECT COUNT(*) INTO v_existe FROM user_sequences WHERE sequence_name = v_seq;
      IF v_existe = 0 THEN
        EXECUTE IMMEDIATE 'CREATE SEQUENCE ' || v_seq || ' START WITH ' || v_max || ' NOCACHE';
      ELSE
        -- la secuencia ya existia: se asegura de que no repita ids ya usados
        EXECUTE IMMEDIATE 'ALTER SEQUENCE ' || v_seq || ' RESTART START WITH ' || v_max;
      END IF;

      -- Se quita el DEFAULT que pudo dejar una version anterior de 03: ahora manda el trigger
      EXECUTE IMMEDIATE 'ALTER TABLE ' || v_tablas(i).tabla || ' MODIFY ' || v_tablas(i).columna || ' DEFAULT NULL';

      EXECUTE IMMEDIATE
        'CREATE OR REPLACE TRIGGER ' || v_trg ||
        ' BEFORE INSERT ON ' || v_tablas(i).tabla ||
        ' FOR EACH ROW WHEN (NEW.' || v_tablas(i).columna || ' IS NULL)' ||
        ' BEGIN :NEW.' || v_tablas(i).columna || ' := ' || v_seq || '.NEXTVAL; END;';
    END IF;
  END LOOP;
END;~');
  paso(2, 'ALTER TABLE Venta ADD (codigo_factura VARCHAR2(20))', q'~ALTER TABLE Venta ADD (codigo_factura VARCHAR2(20))~');
  paso(3, 'CREATE SEQUENCE seq_factura START WITH 1 NOCACHE', q'~CREATE SEQUENCE seq_factura START WITH 1 NOCACHE~');
  paso(4, 'CREATE OR REPLACE TRIGGER trg_venta_codigo BEFORE INSERT ON Venta FOR EACH ROW BEGIN -- Tr', q'~CREATE OR REPLACE TRIGGER trg_venta_codigo
BEFORE INSERT ON Venta
FOR EACH ROW
BEGIN
  -- Trigger basico: incrementa la secuencia y arma el codigo
  :NEW.codigo_factura := 'FV-' || TO_CHAR(NVL(:NEW.fecha_venta, SYSDATE), 'YYYY') || '-'
                         || LPAD(seq_factura.NEXTVAL, 6, '0');
END;~');
  paso(5, 'BEGIN FOR v IN (SELECT id_venta, fecha_venta FROM Venta WHERE codigo_factura IS NULL ORDER', q'~BEGIN
  FOR v IN (SELECT id_venta, fecha_venta FROM Venta WHERE codigo_factura IS NULL ORDER BY fecha_venta, id_venta) LOOP
    UPDATE Venta
       SET codigo_factura = 'FV-' || TO_CHAR(v.fecha_venta, 'YYYY') || '-' || LPAD(seq_factura.NEXTVAL, 6, '0')
     WHERE id_venta = v.id_venta;
  END LOOP;
  COMMIT;
END;~');
  paso(6, 'CREATE UNIQUE INDEX uk_venta_codigo_factura ON Venta (codigo_factura)', q'~CREATE UNIQUE INDEX uk_venta_codigo_factura ON Venta (codigo_factura)~');
  paso(7, 'CREATE OR REPLACE PACKAGE pkg_sucursales AS -- Crea una ciudad si no existe (busca por nom', q'~CREATE OR REPLACE PACKAGE pkg_sucursales AS
  -- Crea una ciudad si no existe (busca por nombre sin importar mayusculas) y devuelve su id
  PROCEDURE obtener_o_crear_ciudad(p_nombre VARCHAR2, p_id OUT NUMBER);

  -- Registra una sucursal nueva en una ciudad existente
  PROCEDURE crear_sucursal(p_nombre VARCHAR2, p_direccion VARCHAR2, p_id_ciudad NUMBER, p_id OUT NUMBER);

  -- Cambia nombre, direccion o ciudad de una sucursal
  PROCEDURE actualizar_sucursal(p_id NUMBER, p_nombre VARCHAR2, p_direccion VARCHAR2, p_id_ciudad NUMBER);

  -- Elimina una sucursal SOLO si no tiene empleados, lotes ni ventas (lo valida antes de borrar)
  PROCEDURE eliminar_sucursal(p_id NUMBER);
END pkg_sucursales;~');
  paso(8, 'CREATE OR REPLACE PACKAGE BODY pkg_sucursales AS -- Excepcion propia + PRAGMA EXCEPTION_IN', q'~CREATE OR REPLACE PACKAGE BODY pkg_sucursales AS

  -- Excepcion propia + PRAGMA EXCEPTION_INIT: le da nombre a un error de Oracle
  e_tiene_dependencias EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tiene_dependencias, -2292);   -- ORA-02292: registros hijos

  PROCEDURE obtener_o_crear_ciudad(p_nombre VARCHAR2, p_id OUT NUMBER) IS
  BEGIN
    IF TRIM(p_nombre) IS NULL THEN
      RAISE_APPLICATION_ERROR(-20050, 'El nombre de la ciudad es obligatorio.');
    END IF;
    SELECT id_ciudad INTO p_id
      FROM Ciudad
     WHERE UPPER(nombre) = UPPER(TRIM(p_nombre))
       AND ROWNUM = 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN                        -- no existe: se crea (el trigger pone el id)
      INSERT INTO Ciudad (nombre) VALUES (TRIM(p_nombre)) RETURNING id_ciudad INTO p_id;
  END obtener_o_crear_ciudad;

  PROCEDURE crear_sucursal(p_nombre VARCHAR2, p_direccion VARCHAR2, p_id_ciudad NUMBER, p_id OUT NUMBER) IS
  BEGIN
    IF TRIM(p_nombre) IS NULL THEN
      RAISE_APPLICATION_ERROR(-20051, 'El nombre de la sucursal es obligatorio.');
    END IF;
    INSERT INTO Sucursal (nombre, direccion, id_ciudad)
    VALUES (TRIM(p_nombre), p_direccion, p_id_ciudad)
    RETURNING id_sucursal INTO p_id;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      RAISE_APPLICATION_ERROR(-20052, 'Ya existe una sucursal con ese nombre.');
  END crear_sucursal;

  PROCEDURE actualizar_sucursal(p_id NUMBER, p_nombre VARCHAR2, p_direccion VARCHAR2, p_id_ciudad NUMBER) IS
  BEGIN
    UPDATE Sucursal SET nombre = TRIM(p_nombre), direccion = p_direccion, id_ciudad = p_id_ciudad
     WHERE id_sucursal = p_id;
    IF SQL%ROWCOUNT = 0 THEN                       -- atributo de cursor implicito
      RAISE_APPLICATION_ERROR(-20053, 'No existe la sucursal ' || p_id || '.');
    END IF;
  END actualizar_sucursal;

  PROCEDURE eliminar_sucursal(p_id NUMBER) IS
    v_empleados NUMBER;
    v_lotes     NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_empleados FROM Empleado WHERE id_sucursal = p_id;
    SELECT COUNT(*) INTO v_lotes     FROM Lote     WHERE id_sucursal = p_id;
    IF v_empleados > 0 OR v_lotes > 0 THEN
      RAISE_APPLICATION_ERROR(-20054, 'No se puede eliminar: la sucursal tiene ' || v_empleados
        || ' empleado(s) y ' || v_lotes || ' lote(s).');
    END IF;
    -- Telefono_Sucursal: SQL dinamico por si la columna tiene otro nombre en tu esquema
    BEGIN
      EXECUTE IMMEDIATE 'DELETE FROM Telefono_Sucursal WHERE id_sucursal = :1' USING p_id;
    EXCEPTION WHEN OTHERS THEN
      IF SQLCODE NOT IN (-904, -942) THEN RAISE; END IF;
    END;
    DELETE FROM Sucursal WHERE id_sucursal = p_id;
  EXCEPTION
    WHEN e_tiene_dependencias THEN                 -- p. ej. ventas historicas
      RAISE_APPLICATION_ERROR(-20055, 'No se puede eliminar: la sucursal tiene ventas registradas.');
  END eliminar_sucursal;

END pkg_sucursales;~');
  paso(9, 'CREATE OR REPLACE PACKAGE pkg_reportes AS -- ===== Tipos compuestos ===== -- REGISTRO defi', q'~CREATE OR REPLACE PACKAGE pkg_reportes AS
  -- ===== Tipos compuestos =====
  -- REGISTRO definido por el usuario: una fila del resumen por sucursal
  TYPE r_resumen_sucursal IS RECORD (
    id_sucursal     NUMBER,
    sucursal        VARCHAR2(100),
    num_ventas      NUMBER,
    total_vendido   NUMBER,
    ticket_promedio NUMBER
  );
  -- COLECCION tipo TABLA ANIDADA de registros
  TYPE t_resumen_sucursal IS TABLE OF r_resumen_sucursal;

  -- COLECCION PUBLICA del paquete (la pide el documento): la llena cargar_resumen_sucursales
  g_resumen t_resumen_sucursal := t_resumen_sucursal();

  -- Coleccion de registros %ROWTYPE (misma estructura que la tabla Lote)
  TYPE t_lotes IS TABLE OF Lote%ROWTYPE;

  -- ARREGLO ASOCIATIVO (index-by): stock indexado por id de medicamento
  TYPE t_stock IS TABLE OF NUMBER INDEX BY PLS_INTEGER;

  -- ===== Funciones =====
  -- Simple (sin parametros): numero de ventas activas de hoy
  FUNCTION fn_ventas_hoy RETURN NUMBER;

  -- Parametrizada: total vendido (ventas ACTIVAS) en un rango; p_id_sucursal NULL = todas
  FUNCTION fn_total_vendido(p_desde DATE, p_hasta DATE, p_id_sucursal NUMBER DEFAULT NULL) RETURN NUMBER;

  -- Parametrizada: unidades vendidas de un medicamento en el rango
  FUNCTION fn_unidades_vendidas(p_id_medicamento NUMBER, p_desde DATE, p_hasta DATE) RETURN NUMBER;

  -- Devuelve una COLECCION: los lotes de un medicamento (BULK COLLECT)
  FUNCTION fn_lotes_de_medicamento(p_id_medicamento NUMBER) RETURN t_lotes;

  -- Devuelve un ARREGLO ASOCIATIVO con el stock vendible de cada medicamento en una sucursal
  FUNCTION fn_stock_sucursal(p_id_sucursal NUMBER) RETURN t_stock;

  -- PIPELINED: permite usar la coleccion en SQL:  SELECT * FROM TABLE(pkg_reportes.fn_resumen_sucursales(...))
  -- (la pantalla de Estadisticas de la app la usa)
  FUNCTION fn_resumen_sucursales(p_desde DATE, p_hasta DATE) RETURN t_resumen_sucursal PIPELINED;

  -- ===== Procedimientos =====
  -- Llena la coleccion publica g_resumen (BULK COLLECT con registros)
  PROCEDURE cargar_resumen_sucursales(p_desde DATE, p_hasta DATE);

  -- Recorre g_resumen e imprime con DBMS_OUTPUT (bucle FOR sobre la coleccion)
  PROCEDURE imprimir_resumen;

  -- CURSOR EXPLICITO SIMPLE (OPEN / FETCH / CLOSE): medicamentos sin stock vendible en ninguna sucursal
  PROCEDURE listar_medicamentos_agotados;

  -- CURSOR PARAMETRIZADO: lotes que vencen dentro de p_dias en una sucursal
  PROCEDURE listar_lotes_por_vencer(p_id_sucursal NUMBER, p_dias NUMBER DEFAULT 30);
END pkg_reportes;~');
  paso(10, 'CREATE OR REPLACE PACKAGE BODY pkg_reportes AS -- Excepcion de usuario e_rango_invalido EX', q'~CREATE OR REPLACE PACKAGE BODY pkg_reportes AS

  -- Excepcion de usuario
  e_rango_invalido EXCEPTION;

  -- Procedimiento privado (no esta en la especificacion): valida el rango de fechas
  PROCEDURE validar_rango(p_desde DATE, p_hasta DATE) IS
  BEGIN
    IF p_desde IS NULL OR p_hasta IS NULL OR p_desde > p_hasta THEN
      RAISE e_rango_invalido;
    END IF;
  END validar_rango;

  FUNCTION fn_ventas_hoy RETURN NUMBER IS
    v_n NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_n
      FROM Venta
     WHERE TRUNC(fecha_venta) = TRUNC(SYSDATE) AND estado = 'ACTIVA';
    RETURN v_n;
  END fn_ventas_hoy;

  FUNCTION fn_total_vendido(p_desde DATE, p_hasta DATE, p_id_sucursal NUMBER DEFAULT NULL) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    validar_rango(p_desde, p_hasta);
    SELECT NVL(SUM(total), 0) INTO v_total
      FROM Venta
     WHERE estado = 'ACTIVA'
       AND TRUNC(fecha_venta) BETWEEN TRUNC(p_desde) AND TRUNC(p_hasta)
       AND (p_id_sucursal IS NULL OR id_sucursal = p_id_sucursal);
    RETURN v_total;
  EXCEPTION
    WHEN e_rango_invalido THEN
      RAISE_APPLICATION_ERROR(-20060, 'Rango de fechas invalido: "desde" debe ser anterior a "hasta".');
  END fn_total_vendido;

  FUNCTION fn_unidades_vendidas(p_id_medicamento NUMBER, p_desde DATE, p_hasta DATE) RETURN NUMBER IS
    v_n NUMBER;
  BEGIN
    SELECT NVL(SUM(vl.cantidad), 0) INTO v_n
      FROM Venta_Lote vl
      JOIN Venta v ON v.id_venta = vl.id_venta AND v.estado = 'ACTIVA'
      JOIN Lote l  ON l.id_lote = vl.id_lote
     WHERE l.id_medicamento = p_id_medicamento
       AND TRUNC(v.fecha_venta) BETWEEN TRUNC(p_desde) AND TRUNC(p_hasta);
    RETURN v_n;
  END fn_unidades_vendidas;

  FUNCTION fn_lotes_de_medicamento(p_id_medicamento NUMBER) RETURN t_lotes IS
    v_lotes t_lotes;
  BEGIN
    SELECT * BULK COLLECT INTO v_lotes            -- BULK COLLECT: todas las filas de una vez
      FROM Lote
     WHERE id_medicamento = p_id_medicamento
     ORDER BY fecha_vencimiento;
    IF v_lotes.COUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20061, 'El medicamento ' || p_id_medicamento || ' no tiene lotes.');
    END IF;
    RETURN v_lotes;
  END fn_lotes_de_medicamento;

  FUNCTION fn_stock_sucursal(p_id_sucursal NUMBER) RETURN t_stock IS
    v_stock t_stock;
  BEGIN
    FOR r IN (SELECT id_medicamento, SUM(cantidad_actual) AS unidades
                FROM Lote
               WHERE id_sucursal = p_id_sucursal AND fecha_vencimiento > TRUNC(SYSDATE)
               GROUP BY id_medicamento) LOOP
      v_stock(r.id_medicamento) := r.unidades;     -- el indice es el id del medicamento
    END LOOP;
    RETURN v_stock;
  END fn_stock_sucursal;

  FUNCTION fn_resumen_sucursales(p_desde DATE, p_hasta DATE) RETURN t_resumen_sucursal PIPELINED IS
    v_fila r_resumen_sucursal;
  BEGIN
    validar_rango(p_desde, p_hasta);
    FOR r IN (SELECT s.id_sucursal, s.nombre,
                     COUNT(v.id_venta) AS num_ventas,
                     NVL(SUM(v.total), 0) AS total
                FROM Sucursal s
                LEFT JOIN Venta v ON v.id_sucursal = s.id_sucursal
                                 AND v.estado = 'ACTIVA'
                                 AND TRUNC(v.fecha_venta) BETWEEN TRUNC(p_desde) AND TRUNC(p_hasta)
               GROUP BY s.id_sucursal, s.nombre
               ORDER BY total DESC) LOOP
      v_fila.id_sucursal     := r.id_sucursal;
      v_fila.sucursal        := r.nombre;
      v_fila.num_ventas      := r.num_ventas;
      v_fila.total_vendido   := r.total;
      v_fila.ticket_promedio := CASE WHEN r.num_ventas > 0 THEN ROUND(r.total / r.num_ventas) ELSE 0 END;
      PIPE ROW (v_fila);                            -- entrega la fila al SELECT que la consume
    END LOOP;
    RETURN;
  EXCEPTION
    WHEN e_rango_invalido THEN
      RAISE_APPLICATION_ERROR(-20060, 'Rango de fechas invalido: "desde" debe ser anterior a "hasta".');
  END fn_resumen_sucursales;

  PROCEDURE cargar_resumen_sucursales(p_desde DATE, p_hasta DATE) IS
  BEGIN
    SELECT * BULK COLLECT INTO g_resumen
      FROM TABLE(fn_resumen_sucursales(p_desde, p_hasta));
  END cargar_resumen_sucursales;

  PROCEDURE imprimir_resumen IS
  BEGIN
    IF g_resumen.COUNT = 0 THEN
      DBMS_OUTPUT.PUT_LINE('La coleccion esta vacia: ejecute primero cargar_resumen_sucursales.');
      RETURN;
    END IF;
    FOR i IN g_resumen.FIRST .. g_resumen.LAST LOOP
      DBMS_OUTPUT.PUT_LINE(RPAD(g_resumen(i).sucursal, 25) || ' ventas: ' || LPAD(g_resumen(i).num_ventas, 4)
        || '  total: ' || TO_CHAR(g_resumen(i).total_vendido, '999G999G990')
        || '  ticket: ' || TO_CHAR(g_resumen(i).ticket_promedio, '999G999G990'));
    END LOOP;
  END imprimir_resumen;

  PROCEDURE listar_medicamentos_agotados IS
    -- CURSOR EXPLICITO SIMPLE
    CURSOR c_agotados IS
      SELECT m.id_medicamento, m.nombre_comercial
        FROM Medicamento m
       WHERE NOT EXISTS (SELECT 1 FROM Lote l
                          WHERE l.id_medicamento = m.id_medicamento
                            AND l.cantidad_actual > 0
                            AND l.fecha_vencimiento > TRUNC(SYSDATE))
       ORDER BY m.nombre_comercial;
    v_med c_agotados%ROWTYPE;                       -- registro con la forma del cursor
  BEGIN
    OPEN c_agotados;
    LOOP
      FETCH c_agotados INTO v_med;
      EXIT WHEN c_agotados%NOTFOUND;
      DBMS_OUTPUT.PUT_LINE('Agotado: ' || v_med.id_medicamento || ' - ' || v_med.nombre_comercial);
    END LOOP;
    IF c_agotados%ROWCOUNT = 0 THEN
      DBMS_OUTPUT.PUT_LINE('No hay medicamentos agotados.');
    END IF;
    CLOSE c_agotados;
  EXCEPTION
    WHEN OTHERS THEN
      IF c_agotados%ISOPEN THEN CLOSE c_agotados; END IF;   -- nunca dejar un cursor abierto
      RAISE;
  END listar_medicamentos_agotados;

  PROCEDURE listar_lotes_por_vencer(p_id_sucursal NUMBER, p_dias NUMBER DEFAULT 30) IS
    -- CURSOR PARAMETRIZADO
    CURSOR c_lotes(cp_sucursal NUMBER, cp_dias NUMBER) IS
      SELECT l.id_lote, m.nombre_comercial, l.cantidad_actual, l.fecha_vencimiento,
             fn_dias_para_vencer(l.id_lote) AS dias
        FROM Lote l JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
       WHERE l.id_sucursal = cp_sucursal
         AND l.cantidad_actual > 0
         AND l.fecha_vencimiento BETWEEN TRUNC(SYSDATE) AND TRUNC(SYSDATE) + cp_dias
       ORDER BY l.fecha_vencimiento;
    v_total NUMBER := 0;
  BEGIN
    IF p_dias IS NULL OR p_dias <= 0 THEN
      RAISE_APPLICATION_ERROR(-20062, 'El numero de dias debe ser mayor que cero.');
    END IF;
    FOR r IN c_lotes(p_id_sucursal, p_dias) LOOP      -- cursor FOR: abre, recorre y cierra solo
      DBMS_OUTPUT.PUT_LINE('Lote ' || r.id_lote || ' ' || r.nombre_comercial || ': ' || r.cantidad_actual
        || ' und, vence en ' || r.dias || ' dia(s)');
      v_total := v_total + r.cantidad_actual;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Total de unidades en riesgo: ' || v_total);
  END listar_lotes_por_vencer;

END pkg_reportes;~');
  paso(11, 'DROP TRIGGER trg_medicamento_auditoria', q'~DROP TRIGGER trg_medicamento_auditoria~');
  paso(12, 'CREATE OR REPLACE TRIGGER trg_medicamento_precio FOR UPDATE OF precio_unitario ON Medicame', q'~CREATE OR REPLACE TRIGGER trg_medicamento_precio
FOR UPDATE OF precio_unitario ON Medicamento
COMPOUND TRIGGER

  c_variacion_maxima CONSTANT NUMBER := 0.5;      -- maximo 50 % de cambio en una sola edicion

  TYPE r_cambio IS RECORD (id_medicamento NUMBER, anterior NUMBER, nuevo NUMBER);
  TYPE t_cambios IS TABLE OF r_cambio INDEX BY PLS_INTEGER;
  v_cambios t_cambios;

  BEFORE EACH ROW IS
  BEGIN
    IF :NEW.precio_unitario <= 0 THEN
      RAISE_APPLICATION_ERROR(-20070, 'El precio debe ser mayor que cero.');
    END IF;
    IF :OLD.precio_unitario > 0
       AND ABS(:NEW.precio_unitario - :OLD.precio_unitario) / :OLD.precio_unitario > c_variacion_maxima THEN
      RAISE_APPLICATION_ERROR(-20071, 'El precio de ' || :OLD.nombre_comercial || ' no puede cambiar mas del '
        || (c_variacion_maxima * 100) || ' % de una vez (de ' || :OLD.precio_unitario || ' a ' || :NEW.precio_unitario || ').');
    END IF;
  END BEFORE EACH ROW;

  AFTER EACH ROW IS
  BEGIN
    IF :OLD.precio_unitario != :NEW.precio_unitario THEN
      v_cambios(v_cambios.COUNT + 1).id_medicamento := :NEW.id_medicamento;
      v_cambios(v_cambios.COUNT).anterior := :OLD.precio_unitario;
      v_cambios(v_cambios.COUNT).nuevo    := :NEW.precio_unitario;
    END IF;
  END AFTER EACH ROW;

  AFTER STATEMENT IS
  BEGIN
    FORALL i IN 1 .. v_cambios.COUNT
      INSERT INTO Auditoria_Precio (id_medicamento, precio_anterior, precio_nuevo)
      VALUES (v_cambios(i).id_medicamento, v_cambios(i).anterior, v_cambios(i).nuevo);
    v_cambios.DELETE;
  END AFTER STATEMENT;

END trg_medicamento_precio;~');
  paso(13, 'CREATE OR REPLACE VIEW vw_pacientes AS SELECT p.id_persona AS id_paciente, p.nombre, p.ape', q'~CREATE OR REPLACE VIEW vw_pacientes AS
SELECT p.id_persona AS id_paciente, p.nombre, p.apellido, p.documento, p.email,
       c.direccion, c.fecha_registro,
       (SELECT MIN(t.numeroTelefono) FROM Telefono_persona t WHERE t.id_persona = p.id_persona) AS telefono
  FROM Persona p
  JOIN Cliente c ON c.id_cliente = p.id_persona~');
  paso(14, 'CREATE OR REPLACE TRIGGER trg_pacientes_instead INSTEAD OF INSERT OR UPDATE OR DELETE ON v', q'~CREATE OR REPLACE TRIGGER trg_pacientes_instead
INSTEAD OF INSERT OR UPDATE OR DELETE ON vw_pacientes
FOR EACH ROW
DECLARE
  v_id NUMBER;
BEGIN
  IF INSERTING THEN
    -- Reutiliza el procedimiento del equipo: Persona + Cliente + Telefono en una sola llamada
    pkg_personas.registrar_persona(p_tipo => 'C', p_nombre => :NEW.nombre, p_apellido => :NEW.apellido,
        p_documento => :NEW.documento, p_email => :NEW.email, p_telefono => :NEW.telefono,
        p_direccion => :NEW.direccion, p_id_persona => v_id);

  ELSIF UPDATING THEN
    pkg_mantenimiento.actualizar_cliente(:OLD.id_paciente, :NEW.nombre, :NEW.apellido,
        :NEW.documento, :NEW.email, :NEW.direccion);
    IF NVL(:NEW.telefono, '#') != NVL(:OLD.telefono, '#') THEN
      DELETE FROM Telefono_persona WHERE id_persona = :OLD.id_paciente;
      IF :NEW.telefono IS NOT NULL THEN
        INSERT INTO Telefono_persona (id_persona, numeroTelefono) VALUES (:OLD.id_paciente, :NEW.telefono);
      END IF;
    END IF;

  ELSE -- DELETING
    pkg_mantenimiento.eliminar_cliente(:OLD.id_paciente);
  END IF;
END;~');
  paso(15, 'CREATE OR REPLACE PACKAGE pkg_traslados AS -- Traslada p_cantidad unidades de un lote a ot', q'~CREATE OR REPLACE PACKAGE pkg_traslados AS
  -- Traslada p_cantidad unidades de un lote a otra sucursal. Devuelve el id del lote creado en destino.
  -- p_id_empleado: empleado de la sucursal DESTINO que recibe y valida el lote.
  PROCEDURE trasladar_stock(p_id_lote NUMBER, p_id_sucursal_destino NUMBER, p_cantidad NUMBER,
                            p_id_empleado NUMBER, p_id_lote_nuevo OUT NUMBER);
END pkg_traslados;~');
  paso(16, 'CREATE OR REPLACE PACKAGE BODY pkg_traslados AS PROCEDURE trasladar_stock(p_id_lote NUMBER', q'~CREATE OR REPLACE PACKAGE BODY pkg_traslados AS

  PROCEDURE trasladar_stock(p_id_lote NUMBER, p_id_sucursal_destino NUMBER, p_cantidad NUMBER,
                            p_id_empleado NUMBER, p_id_lote_nuevo OUT NUMBER) IS
    v_lote     Lote%ROWTYPE;                        -- REGISTRO con la forma de la tabla
    v_suc_emp  Empleado.id_sucursal%TYPE;
  BEGIN
    SAVEPOINT sp_traslado;

    BEGIN
      SELECT * INTO v_lote FROM Lote WHERE id_lote = p_id_lote FOR UPDATE;   -- bloquea el lote
    EXCEPTION WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20080, 'No existe el lote ' || p_id_lote || '.');
    END;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
      RAISE_APPLICATION_ERROR(-20081, 'La cantidad a trasladar debe ser mayor que cero.');
    ELSIF p_cantidad > v_lote.cantidad_actual THEN
      RAISE_APPLICATION_ERROR(-20082, 'El lote solo tiene ' || v_lote.cantidad_actual || ' unidades.');
    ELSIF v_lote.id_sucursal = p_id_sucursal_destino THEN
      RAISE_APPLICATION_ERROR(-20083, 'La sucursal de destino es la misma del lote.');
    ELSIF v_lote.fecha_vencimiento <= TRUNC(SYSDATE) THEN
      RAISE_APPLICATION_ERROR(-20084, 'No se trasladan lotes vencidos.');
    END IF;

    SELECT id_sucursal INTO v_suc_emp FROM Empleado WHERE id_empleado = p_id_empleado;
    IF v_suc_emp != p_id_sucursal_destino THEN
      RAISE_APPLICATION_ERROR(-20085, 'El empleado que recibe debe pertenecer a la sucursal de destino.');
    END IF;

    -- a) sale del origen
    UPDATE Lote SET cantidad_actual = cantidad_actual - p_cantidad WHERE id_lote = p_id_lote;

    -- b) entra al destino: mismo medicamento, proveedor y fechas (el trigger asigna el id)
    INSERT INTO Lote (cantidad_inicial, cantidad_actual, fecha_fabricacion, fecha_vencimiento,
                      id_sucursal, id_proveedor, id_medicamento, id_empleado)
    VALUES (p_cantidad, p_cantidad, v_lote.fecha_fabricacion, v_lote.fecha_vencimiento,
            p_id_sucursal_destino, v_lote.id_proveedor, v_lote.id_medicamento, p_id_empleado)
    RETURNING id_lote INTO p_id_lote_nuevo;

    COMMIT;                                          -- las dos operaciones quedan confirmadas
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      ROLLBACK TO sp_traslado;
      RAISE_APPLICATION_ERROR(-20086, 'El empleado ' || p_id_empleado || ' no existe.');
    WHEN OTHERS THEN
      ROLLBACK TO sp_traslado;                       -- deshace SOLO lo de este traslado
      RAISE;                                         -- y avisa el error original
  END trasladar_stock;

END pkg_traslados;~');
  paso(17, 'CREATE INDEX idx_lote_med_suc_venc ON Lote (id_medicamento, id_sucursal, fecha_vencimiento', q'~CREATE INDEX idx_lote_med_suc_venc ON Lote (id_medicamento, id_sucursal, fecha_vencimiento)~');
  paso(18, 'CREATE INDEX idx_venta_dia ON Venta (TRUNC(fecha_venta))', q'~CREATE INDEX idx_venta_dia ON Venta (TRUNC(fecha_venta))~');
  paso(19, 'CREATE INDEX idx_persona_apellido_upper ON Persona (UPPER(apellido))', q'~CREATE INDEX idx_persona_apellido_upper ON Persona (UPPER(apellido))~');
  paso(20, 'ALTER INDEX idx_lote_med_suc_venc MONITORING USAGE', q'~ALTER INDEX idx_lote_med_suc_venc MONITORING USAGE~');
  paso(21, 'ALTER INDEX idx_venta_dia MONITORING USAGE', q'~ALTER INDEX idx_venta_dia MONITORING USAGE~');
  paso(22, 'ALTER INDEX idx_persona_apellido_upper MONITORING USAGE', q'~ALTER INDEX idx_persona_apellido_upper MONITORING USAGE~');
  paso(23, 'BEGIN DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER, cascade => TRUE); END;', q'~BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER, cascade => TRUE);
END;~');
  paso(24, 'DECLARE PROCEDURE dar(p_sql VARCHAR2) IS BEGIN EXECUTE IMMEDIATE p_sql; EXCEPTION WHEN OTH', q'~DECLARE
  PROCEDURE dar(p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE NOT IN (-1917, -1919, -942, -4042) THEN RAISE; END IF;
  END;
BEGIN
  dar('GRANT EXECUTE ON pkg_sucursales TO admin_farmacia');
  dar('GRANT EXECUTE ON pkg_reportes   TO admin_farmacia');
  dar('GRANT EXECUTE ON pkg_traslados  TO admin_farmacia');
  dar('GRANT EXECUTE ON pkg_reportes   TO gerencia');
  dar('GRANT EXECUTE ON pkg_traslados  TO administrador_sucursal');
  dar('GRANT EXECUTE ON pkg_traslados  TO regente');
  dar('GRANT SELECT, INSERT, UPDATE ON vw_pacientes TO vendedor');
  dar('GRANT SELECT, INSERT, UPDATE ON vw_pacientes TO regente');
  dar('GRANT SELECT, INSERT, UPDATE, DELETE ON vw_pacientes TO administrador_sucursal');
  dar('GRANT ALL ON vw_pacientes TO admin_farmacia');
  dar('GRANT SELECT ON vw_pacientes TO gerencia');
  dar('GRANT SELECT ON vw_pacientes TO auditor');
END;~');

  -- Resumen: objetos que hayan quedado invalidos
  FOR o IN (SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID' ORDER BY 1, 2) LOOP
    v_error := v_error + 1;
    anotar(0, 'INVALIDO', o.object_type || ' ' || o.object_name || ' (ver: SELECT * FROM user_errors)');
  END LOOP;
  anotar(0, 'RESUMEN', v_ok || ' ok, ' || v_existia || ' ya existian u omitidos, ' || v_error || ' con error');
  COMMIT;
END;
