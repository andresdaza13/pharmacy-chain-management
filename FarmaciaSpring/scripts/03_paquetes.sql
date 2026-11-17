-- =====================================================================
-- 03_paquetes.sql  (adaptado al esquema REAL de FARMACIA_APP)
-- EJECUTAR COMO: farmacia_app. En DBeaver usa la version dbeaver/03_paquetes_DBEAVER.sql
--
-- QUE HACE
--   0. Respalda el codigo de TODOS tus paquetes en la tabla respaldo_paquetes.
--   1. Borra los paquetes de prueba que quedaron INVALIDOS (pkg_manejo_ventas,
--      pkg_manejo_suministros): fueron escritos para otro diseño de tablas.
--   3. pkg_inventario   -> Medicamento y Lote (incluye registrar_lote del documento).
--   4. pkg_mantenimiento -> Proveedor + editar/eliminar Cliente y Empleado.
--
-- QUE NO TOCA (es del equipo y ya funciona):
--   pkg_personas (registrar_persona), pkg_ventas (registrar_venta, agregar_medicamento,
--   anular_venta, fn_total_venta) y los triggers trg_venta_bi, trg_venta_lote_bi,
--   trg_venta_lote_ai, trg_venta_lote_inmutable.
-- =====================================================================

-- 0. Respaldo de paquetes (se acumula: cada ejecucion guarda una "foto" con su fecha)
CREATE TABLE respaldo_paquetes AS
SELECT SYSDATE AS fecha, name, type, line, text FROM user_source WHERE 1 = 0;

INSERT INTO respaldo_paquetes
SELECT SYSDATE, name, type, line, text FROM user_source WHERE type IN ('PACKAGE', 'PACKAGE BODY');

COMMIT;

-- 1. Paquetes de prueba invalidos
DROP PACKAGE pkg_manejo_suministros;
DROP PACKAGE pkg_manejo_ventas;

-- 2. IDs automaticos: los generan TRIGGERS con secuencias (ver 08_requisitos_proyecto.sql),
--    o IDENTITY en las tablas que ya lo tenian (Persona, Venta).

-- 3. ===================== INVENTARIO: Medicamento y Lote =====================
CREATE OR REPLACE PACKAGE pkg_inventario AS
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
END pkg_inventario;
/

CREATE OR REPLACE PACKAGE BODY pkg_inventario AS

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

END pkg_inventario;
/

-- 4. ===================== MANTENIMIENTO: Proveedor, Cliente y Empleado =====================
-- La CREACION de personas es de pkg_personas.registrar_persona (del equipo).
-- Aqui solo se editan y eliminan.
CREATE OR REPLACE PACKAGE pkg_mantenimiento AS
    PROCEDURE crear_proveedor(p_nit VARCHAR2, p_nombre VARCHAR2, p_direccion VARCHAR2, p_id OUT NUMBER);
    PROCEDURE actualizar_proveedor(p_id NUMBER, p_nit VARCHAR2, p_nombre VARCHAR2, p_direccion VARCHAR2);
    PROCEDURE eliminar_proveedor(p_id NUMBER);

    PROCEDURE actualizar_cliente(p_id NUMBER, p_nombre VARCHAR2, p_apellido VARCHAR2,
                                 p_documento VARCHAR2, p_email VARCHAR2, p_direccion VARCHAR2);
    PROCEDURE eliminar_cliente(p_id NUMBER);

    PROCEDURE actualizar_empleado(p_id NUMBER, p_nombre VARCHAR2, p_apellido VARCHAR2, p_documento VARCHAR2,
                                  p_email VARCHAR2, p_cargo VARCHAR2, p_salario NUMBER, p_id_sucursal NUMBER);
    PROCEDURE eliminar_empleado(p_id NUMBER);
END pkg_mantenimiento;
/

CREATE OR REPLACE PACKAGE BODY pkg_mantenimiento AS

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

END pkg_mantenimiento;
/
