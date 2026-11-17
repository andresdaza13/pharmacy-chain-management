-- =====================================================================
-- 05_usuario_empleado.sql
-- EJECUTAR COMO: farmacia (conexion XEPDB1)  -> Run Script (F5)
-- Liga cada USUARIO DE ORACLE con su EMPLEADO. Asi, cuando ese usuario inicia sesion:
--   * la venta se registra a nombre de ese empleado y en SU sucursal (MER: Empleado registra Venta,
--     Sucursal realiza Venta),
--   * el lote se registra con ese empleado y esa sucursal,
--   * en la venta solo ve el stock de su sucursal.
-- Un usuario SIN vinculo (p. ej. el administrador) puede usar la app: elige el empleado a mano.
-- =====================================================================
CREATE TABLE usuario_empleado (
    username     VARCHAR2(128) PRIMARY KEY,          -- en MAYUSCULAS, como lo guarda Oracle
    id_empleado  NUMBER NOT NULL REFERENCES Empleado(id_empleado)
);

-- 1. Mira que empleados tienes y en que sucursal estan:
SELECT e.id_empleado, p.nombre, p.apellido, e.cargo, s.nombre AS sucursal
  FROM Empleado e
  JOIN Persona p  ON p.id_persona  = e.id_empleado
  JOIN Sucursal s ON s.id_sucursal = e.id_sucursal
 ORDER BY e.id_empleado;

-- 2. Liga el usuario de Oracle con el id_empleado que corresponda (cambia el numero):
-- INSERT INTO usuario_empleado (username, id_empleado) VALUES ('ORA_VENDEDOR', 1);
-- COMMIT;

-- Para cambiar o quitar un vinculo:
-- UPDATE usuario_empleado SET id_empleado = 2 WHERE username = 'ORA_VENDEDOR';
-- DELETE FROM usuario_empleado WHERE username = 'ORA_VENDEDOR';
