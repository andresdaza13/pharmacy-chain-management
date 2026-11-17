DECLARE
  -- =====================================================================
  -- 03_paquetes   (version para DBeaver, generada desde el script original)
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
      USING '03_paquetes', p_paso, p_estado, SUBSTR(p_detalle, 1, 900);
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

  paso(1, 'CREATE TABLE respaldo_paquetes AS SELECT SYSDATE AS fecha, name, type, line, text FROM use', q'~CREATE TABLE respaldo_paquetes AS
SELECT SYSDATE AS fecha, name, type, line, text FROM user_source WHERE 1 = 0~');
  paso(2, 'INSERT INTO respaldo_paquetes SELECT SYSDATE, name, type, line, text FROM user_source WHER', q'~INSERT INTO respaldo_paquetes
SELECT SYSDATE, name, type, line, text FROM user_source WHERE type IN ('PACKAGE', 'PACKAGE BODY')~');
  paso(3, 'COMMIT', q'~COMMIT~');
  paso(4, 'DROP PACKAGE pkg_manejo_suministros', q'~DROP PACKAGE pkg_manejo_suministros~');
  paso(5, 'DROP PACKAGE pkg_manejo_ventas', q'~DROP PACKAGE pkg_manejo_ventas~');
  paso(6, 'CREATE OR REPLACE PACKAGE pkg_inventario AS PROCEDURE crear_medicamento(p_nombre VARCHAR2,', q'~CREATE OR REPLACE PACKAGE pkg_inventario AS
    PROCEDURE crear_medicamento(p_nombre VARCHAR2, p_nombre_generico VARCHAR2, p_presentacion VARCHAR2,
                                p_id_categoria NUMBER, p_precio NUMBER, p_requiere_receta VARCHAR2,
                                p_id OUT NUMBER);
    PROCEDURE actualizar_medicamento(p_id NUMBER, p_nombre VARCHAR2, p_nombre_generico VARCHAR2,
                                     p_presentacion VARCHAR2, p_id_categoria NUMBER, p_precio NUMBER,
                                     p_requiere_receta VARCHAR2);
    PROCEDURE eliminar_medicamento(p_id NUMBER);

    -- registrar_lote (documento): medicamento + sucursal + proveedor + empleado responsable
    PROCEDURE registrar_lote(p_id_medicamento NUMBER, p_id_sucursal NUMBER, p_id_proveedor NUMBER,
                             p_id_empleado NUMBER, p_fecha_fabricacion DATE, p_fecha_vencimiento DATE,
                             p_cantidad NUMBER, p_id OUT NUMBER);
    PROCEDURE actualizar_lote(p_id NUMBER, p_fecha_fabricacion DATE, p_fecha_vencimiento DATE,
                              p_cantidad_actual NUMBER);
    PROCEDURE eliminar_lote(p_id NUMBER);
END pkg_inventario;~');
  paso(7, 'CREATE OR REPLACE PACKAGE BODY pkg_inventario AS PROCEDURE crear_medicamento(p_nombre VARC', q'~CREATE OR REPLACE PACKAGE BODY pkg_inventario AS

    PROCEDURE crear_medicamento(p_nombre VARCHAR2, p_nombre_generico VARCHAR2, p_presentacion VARCHAR2,
                                p_id_categoria NUMBER, p_precio NUMBER, p_requiere_receta VARCHAR2,
                                p_id OUT NUMBER) IS
    BEGIN
        INSERT INTO Medicamento (nombre_comercial, nombre_generico, presentacion, id_categoria,
                                 precio_unitario, requiere_receta)
        VALUES (p_nombre, p_nombre_generico, p_presentacion, p_id_categoria, p_precio, p_requiere_receta)
        RETURNING id_medicamento INTO p_id;
    END crear_medicamento;

    PROCEDURE actualizar_medicamento(p_id NUMBER, p_nombre VARCHAR2, p_nombre_generico VARCHAR2,
                                     p_presentacion VARCHAR2, p_id_categoria NUMBER, p_precio NUMBER,
                                     p_requiere_receta VARCHAR2) IS
    BEGIN
        UPDATE Medicamento
           SET nombre_comercial = p_nombre, nombre_generico = p_nombre_generico,
               presentacion = p_presentacion, id_categoria = p_id_categoria,
               precio_unitario = p_precio, requiere_receta = p_requiere_receta
         WHERE id_medicamento = p_id;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20040, 'No existe el medicamento ' || p_id || '.');
        END IF;
    END actualizar_medicamento;

    PROCEDURE eliminar_medicamento(p_id NUMBER) IS
    BEGIN
        DELETE FROM Medicamento WHERE id_medicamento = p_id;
    END eliminar_medicamento;

    PROCEDURE registrar_lote(p_id_medicamento NUMBER, p_id_sucursal NUMBER, p_id_proveedor NUMBER,
                             p_id_empleado NUMBER, p_fecha_fabricacion DATE, p_fecha_vencimiento DATE,
                             p_cantidad NUMBER, p_id OUT NUMBER) IS
        v_suc_empleado Empleado.id_sucursal%TYPE;
    BEGIN
        -- La tabla ya tiene CHECK (vencimiento > fabricacion, cantidad > 0); aqui se valida
        -- ANTES para dar un mensaje claro en vez de "check constraint violated".
        IF p_fecha_vencimiento <= p_fecha_fabricacion THEN
            RAISE_APPLICATION_ERROR(-20041, 'La fecha de vencimiento debe ser posterior a la de fabricacion.');
        END IF;
        IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
            RAISE_APPLICATION_ERROR(-20042, 'La cantidad del lote debe ser mayor que cero.');
        END IF;
        BEGIN
            SELECT id_sucursal INTO v_suc_empleado FROM Empleado WHERE id_empleado = p_id_empleado;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20043, 'El empleado responsable no existe.');
        END;
        IF v_suc_empleado != p_id_sucursal THEN
            RAISE_APPLICATION_ERROR(-20044,
                'El empleado que valida el lote debe pertenecer a la sucursal que lo recibe.');
        END IF;

        INSERT INTO Lote (cantidad_inicial, cantidad_actual, fecha_fabricacion, fecha_vencimiento,
                          id_sucursal, id_proveedor, id_medicamento, id_empleado)
        VALUES (p_cantidad, p_cantidad, p_fecha_fabricacion, p_fecha_vencimiento,
                p_id_sucursal, p_id_proveedor, p_id_medicamento, p_id_empleado)
        RETURNING id_lote INTO p_id;
    END registrar_lote;

    PROCEDURE actualizar_lote(p_id NUMBER, p_fecha_fabricacion DATE, p_fecha_vencimiento DATE,
                              p_cantidad_actual NUMBER) IS
    BEGIN
        UPDATE Lote
           SET fecha_fabricacion = p_fecha_fabricacion, fecha_vencimiento = p_fecha_vencimiento,
               cantidad_actual = p_cantidad_actual
         WHERE id_lote = p_id;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20045, 'No existe el lote ' || p_id || '.');
        END IF;
    END actualizar_lote;

    PROCEDURE eliminar_lote(p_id NUMBER) IS
    BEGIN
        DELETE FROM Lote WHERE id_lote = p_id;
    END eliminar_lote;

END pkg_inventario;~');
  paso(8, 'CREATE OR REPLACE PACKAGE pkg_mantenimiento AS PROCEDURE crear_proveedor(p_nit VARCHAR2, p', q'~CREATE OR REPLACE PACKAGE pkg_mantenimiento AS
    PROCEDURE crear_proveedor(p_nit VARCHAR2, p_nombre VARCHAR2, p_direccion VARCHAR2, p_id OUT NUMBER);
    PROCEDURE actualizar_proveedor(p_id NUMBER, p_nit VARCHAR2, p_nombre VARCHAR2, p_direccion VARCHAR2);
    PROCEDURE eliminar_proveedor(p_id NUMBER);

    PROCEDURE actualizar_cliente(p_id NUMBER, p_nombre VARCHAR2, p_apellido VARCHAR2,
                                 p_documento VARCHAR2, p_email VARCHAR2, p_direccion VARCHAR2);
    PROCEDURE eliminar_cliente(p_id NUMBER);

    PROCEDURE actualizar_empleado(p_id NUMBER, p_nombre VARCHAR2, p_apellido VARCHAR2, p_documento VARCHAR2,
                                  p_email VARCHAR2, p_cargo VARCHAR2, p_salario NUMBER, p_id_sucursal NUMBER);
    PROCEDURE eliminar_empleado(p_id NUMBER);
END pkg_mantenimiento;~');
  paso(9, 'CREATE OR REPLACE PACKAGE BODY pkg_mantenimiento AS PROCEDURE crear_proveedor(p_nit VARCHA', q'~CREATE OR REPLACE PACKAGE BODY pkg_mantenimiento AS

    PROCEDURE crear_proveedor(p_nit VARCHAR2, p_nombre VARCHAR2, p_direccion VARCHAR2, p_id OUT NUMBER) IS
    BEGIN
        INSERT INTO Proveedor (nit, nombre, direccion)
        VALUES (p_nit, p_nombre, p_direccion)
        RETURNING id_proveedor INTO p_id;
    END crear_proveedor;

    PROCEDURE actualizar_proveedor(p_id NUMBER, p_nit VARCHAR2, p_nombre VARCHAR2, p_direccion VARCHAR2) IS
    BEGIN
        UPDATE Proveedor SET nit = p_nit, nombre = p_nombre, direccion = p_direccion
         WHERE id_proveedor = p_id;
    END actualizar_proveedor;

    PROCEDURE eliminar_proveedor(p_id NUMBER) IS
    BEGIN
        DELETE FROM Proveedor WHERE id_proveedor = p_id;
    END eliminar_proveedor;

    -- Datos comunes de Persona (cliente y empleado comparten este UPDATE)
    PROCEDURE actualizar_persona(p_id NUMBER, p_nombre VARCHAR2, p_apellido VARCHAR2,
                                 p_documento VARCHAR2, p_email VARCHAR2) IS
    BEGIN
        UPDATE Persona
           SET nombre = p_nombre, apellido = p_apellido, documento = p_documento, email = p_email
         WHERE id_persona = p_id;
    END actualizar_persona;

    -- Borra los telefonos y la persona; el subtipo (Cliente/Empleado) se borra antes
    PROCEDURE eliminar_persona(p_id NUMBER) IS
    BEGIN
        DELETE FROM Telefono_persona WHERE id_persona = p_id;
        DELETE FROM Persona WHERE id_persona = p_id;
    END eliminar_persona;

    PROCEDURE actualizar_cliente(p_id NUMBER, p_nombre VARCHAR2, p_apellido VARCHAR2,
                                 p_documento VARCHAR2, p_email VARCHAR2, p_direccion VARCHAR2) IS
    BEGIN
        actualizar_persona(p_id, p_nombre, p_apellido, p_documento, p_email);
        UPDATE Cliente SET direccion = p_direccion WHERE id_cliente = p_id;
    END actualizar_cliente;

    PROCEDURE eliminar_cliente(p_id NUMBER) IS
    BEGIN
        DELETE FROM Cliente WHERE id_cliente = p_id;   -- si tiene ventas: ORA-02292 y no se borra nada
        eliminar_persona(p_id);
    END eliminar_cliente;

    PROCEDURE actualizar_empleado(p_id NUMBER, p_nombre VARCHAR2, p_apellido VARCHAR2, p_documento VARCHAR2,
                                  p_email VARCHAR2, p_cargo VARCHAR2, p_salario NUMBER, p_id_sucursal NUMBER) IS
    BEGIN
        actualizar_persona(p_id, p_nombre, p_apellido, p_documento, p_email);
        UPDATE Empleado SET cargo = UPPER(p_cargo), salario = p_salario, id_sucursal = p_id_sucursal
         WHERE id_empleado = p_id;
    END actualizar_empleado;

    PROCEDURE eliminar_empleado(p_id NUMBER) IS
    BEGIN
        -- usuario_empleado se crea en 05: se usa SQL dinamico para no depender del orden de los scripts
        BEGIN
            EXECUTE IMMEDIATE 'DELETE FROM usuario_empleado WHERE id_empleado = :1' USING p_id;
        EXCEPTION WHEN OTHERS THEN
            IF SQLCODE != -942 THEN RAISE; END IF;
        END;
        DELETE FROM Empleado WHERE id_empleado = p_id;  -- si tiene ventas o lotes: ORA-02292
        eliminar_persona(p_id);
    END eliminar_empleado;

END pkg_mantenimiento;~');

  -- Resumen: objetos que hayan quedado invalidos
  FOR o IN (SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID' ORDER BY 1, 2) LOOP
    v_error := v_error + 1;
    anotar(0, 'INVALIDO', o.object_type || ' ' || o.object_name || ' (ver: SELECT * FROM user_errors)');
  END LOOP;
  anotar(0, 'RESUMEN', v_ok || ' ok, ' || v_existia || ' ya existian u omitidos, ' || v_error || ' con error');
  COMMIT;
END;
