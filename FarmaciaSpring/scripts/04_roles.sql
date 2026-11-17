-- =====================================================================
-- 04_roles.sql
-- EJECUTAR COMO: farmacia (tiene DBA), conexion con Nombre del Servicio XEPDB1
--                -> Run Script (F5), NO Ctrl+Intro.
-- Se puede ejecutar varias veces sin errores.
--
-- CAMBIOS respecto a la version anterior:
--  * Los roles ya no empiezan con "rol_": admin_farmacia, gerencia, administrador_sucursal,
--    regente, vendedor, auditor.
--  * Cada rol recibe CREATE SESSION. Sin eso, un usuario que solo tenga el rol NO PUEDE iniciar
--    sesion (ORA-01045). Era lo que fallaba sobre todo con vendedor.
--  * Se agrega SELECT sobre Ciudad (Sucursal depende de ella) y sobre las secuencias, para que
--    un vendedor pueda insertar clientes y ventas (seq_persona, seq_venta...).
--  * Los roles se crean tolerando que ya existan y se verifica que quedaron creados.
--
-- NOMBRES: en Oracle un rol y un usuario NO pueden llamarse igual. No crees un usuario llamado
-- "vendedor" ni "regente"; usa por ejemplo ora_vendedor o vendedor1.
--
-- LA APLICACION JAVA: estos permisos solo aplican a quien se conecte directo a Oracle con ese
-- usuario (por ejemplo desde SQL Developer). La aplicacion ejecuta los procedimientos con la
-- conexion de application.properties (farmacia); lo que puede hacer cada rol dentro de la
-- aplicacion lo definen Operacion.java y SeguridadConfig.java.
-- Equivalencia al iniciar sesion en la app con un usuario de Oracle (AutenticacionFarmacia.java):
--     DBA o admin_farmacia -> Administrador       | gerencia -> Gerencia (reportes, solo lectura)
--     administrador_sucursal -> Admin. sucursal   | regente  -> Regente (ventas con receta + lotes)
--     vendedor -> Vendedor (ventas sin receta)    | auditor  -> Auditor (solo lectura)
-- Los permisos EXECUTE sobre pkg_farmacia, las funciones fn_* y las vistas de reportes se dan
-- en 06_logica_negocio.sql (porque esos objetos se crean alli).
-- =====================================================================

-- 0. (OPCIONAL) Roles de la version anterior. Ejecutalo solo si los creaste y ya no los usas.
--    OJO: al borrar un rol, los usuarios que lo tenian lo pierden.
-- DROP ROLE rol_admin_farmacia;  DROP ROLE rol_gerencia;  DROP ROLE rol_administrador_sucursal;
-- DROP ROLE rol_regente;         DROP ROLE rol_vendedor;  DROP ROLE rol_auditor;
-- DROP ROLE rol_admin;           DROP ROLE rol_inventario;

-- 1. Crear los roles (si ya existen, se ignora ORA-01921)
BEGIN
  FOR r IN (SELECT column_value AS nombre FROM TABLE(sys.odcivarchar2list(
              'ADMIN_FARMACIA','GERENCIA','ADMINISTRADOR_SUCURSAL','REGENTE','VENDEDOR','AUDITOR'))) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'CREATE ROLE ' || r.nombre;
    EXCEPTION WHEN OTHERS THEN
      IF SQLCODE != -1921 THEN RAISE; END IF;
    END;
  END LOOP;
END;
/

-- 2. Verificar que los 6 existen DE VERDAD como roles. ORA-01921 tambien sale cuando el nombre
--    lo usa un USUARIO; en ese caso los GRANT siguientes irian al usuario y no al rol.
DECLARE
  v_total NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_total FROM dba_roles
   WHERE role IN ('ADMIN_FARMACIA','GERENCIA','ADMINISTRADOR_SUCURSAL','REGENTE','VENDEDOR','AUDITOR');
  IF v_total < 6 THEN
    RAISE_APPLICATION_ERROR(-20001,
      'Solo existen ' || v_total || ' de 6 roles. Revisa si hay un USUARIO con el mismo nombre que un rol.');
  END IF;
END;
/

-- 3. Permiso para iniciar sesion (necesario en TODOS los roles)
GRANT CREATE SESSION TO admin_farmacia;
GRANT CREATE SESSION TO gerencia;
GRANT CREATE SESSION TO administrador_sucursal;
GRANT CREATE SESSION TO regente;
GRANT CREATE SESSION TO vendedor;
GRANT CREATE SESSION TO auditor;

-- 4. ADMIN_FARMACIA: todo
GRANT ALL ON Persona            TO admin_farmacia;
GRANT ALL ON Telefono_persona   TO admin_farmacia;
GRANT ALL ON Cliente            TO admin_farmacia;
GRANT ALL ON Ciudad             TO admin_farmacia;
GRANT ALL ON Sucursal           TO admin_farmacia;
GRANT ALL ON Telefono_Sucursal  TO admin_farmacia;
GRANT ALL ON Empleado           TO admin_farmacia;
GRANT ALL ON Categoria          TO admin_farmacia;
GRANT ALL ON Medicamento        TO admin_farmacia;
GRANT ALL ON Proveedor          TO admin_farmacia;
GRANT ALL ON Telefono           TO admin_farmacia;
GRANT ALL ON Lote               TO admin_farmacia;
GRANT ALL ON Venta              TO admin_farmacia;
GRANT ALL ON Venta_Lote         TO admin_farmacia;

-- 5. AUDITOR: solo lectura
GRANT SELECT ON Persona            TO auditor;
GRANT SELECT ON Telefono_persona   TO auditor;
GRANT SELECT ON Cliente            TO auditor;
GRANT SELECT ON Ciudad             TO auditor;
GRANT SELECT ON Sucursal           TO auditor;
GRANT SELECT ON Telefono_Sucursal  TO auditor;
GRANT SELECT ON Empleado           TO auditor;
GRANT SELECT ON Categoria          TO auditor;
GRANT SELECT ON Medicamento        TO auditor;
GRANT SELECT ON Proveedor          TO auditor;
GRANT SELECT ON Telefono           TO auditor;
GRANT SELECT ON Lote               TO auditor;
GRANT SELECT ON Venta              TO auditor;
GRANT SELECT ON Venta_Lote         TO auditor;

-- 6. GERENCIA
GRANT SELECT ON Persona            TO gerencia;
GRANT SELECT ON Telefono_persona   TO gerencia;
GRANT SELECT ON Cliente            TO gerencia;
GRANT SELECT ON Ciudad             TO gerencia;
GRANT SELECT ON Sucursal           TO gerencia;
GRANT SELECT ON Telefono_Sucursal  TO gerencia;
GRANT SELECT ON Empleado           TO gerencia;
GRANT SELECT ON Lote               TO gerencia;
GRANT SELECT ON Venta              TO gerencia;
GRANT SELECT ON Venta_Lote         TO gerencia;
GRANT SELECT, INSERT, UPDATE ON Categoria   TO gerencia;
GRANT SELECT, INSERT, UPDATE ON Medicamento TO gerencia;
GRANT SELECT, INSERT, UPDATE ON Proveedor   TO gerencia;
GRANT SELECT, INSERT, UPDATE ON Telefono    TO gerencia;

-- 7. ADMINISTRADOR_SUCURSAL
GRANT SELECT ON Cliente            TO administrador_sucursal;
GRANT SELECT ON Ciudad             TO administrador_sucursal;
GRANT SELECT ON Sucursal           TO administrador_sucursal;
GRANT SELECT ON Telefono_Sucursal  TO administrador_sucursal;
GRANT SELECT ON Categoria          TO administrador_sucursal;
GRANT SELECT ON Medicamento        TO administrador_sucursal;
GRANT SELECT ON Proveedor          TO administrador_sucursal;
GRANT SELECT ON Telefono           TO administrador_sucursal;
GRANT SELECT ON Venta              TO administrador_sucursal;
GRANT SELECT ON Venta_Lote         TO administrador_sucursal;
GRANT SELECT, INSERT, UPDATE ON Persona          TO administrador_sucursal;
GRANT SELECT, INSERT, UPDATE ON Telefono_persona TO administrador_sucursal;
GRANT SELECT, INSERT, UPDATE ON Empleado         TO administrador_sucursal;
GRANT SELECT, INSERT, UPDATE ON Lote             TO administrador_sucursal;

-- 8. REGENTE FARMACEUTICO
GRANT SELECT ON Ciudad             TO regente;
GRANT SELECT ON Sucursal           TO regente;
GRANT SELECT ON Telefono_Sucursal  TO regente;
GRANT SELECT ON Categoria          TO regente;
GRANT SELECT, INSERT, UPDATE ON Medicamento TO regente;
GRANT SELECT, INSERT, UPDATE ON Proveedor   TO regente;
GRANT SELECT, INSERT, UPDATE ON Telefono    TO regente;
GRANT SELECT, INSERT, UPDATE ON Lote        TO regente;
GRANT SELECT, INSERT ON Persona          TO regente;
GRANT SELECT, INSERT ON Telefono_persona TO regente;
GRANT SELECT, INSERT ON Cliente          TO regente;
GRANT SELECT, INSERT ON Venta            TO regente;
GRANT SELECT, INSERT ON Venta_Lote       TO regente;

-- 9. VENDEDOR
GRANT SELECT ON Ciudad             TO vendedor;
GRANT SELECT ON Sucursal           TO vendedor;
GRANT SELECT ON Telefono_Sucursal  TO vendedor;
GRANT SELECT ON Categoria          TO vendedor;
GRANT SELECT ON Medicamento        TO vendedor;
GRANT SELECT ON Lote               TO vendedor;
GRANT UPDATE (cantidad_actual) ON Lote TO vendedor;   -- descontar stock al vender
GRANT SELECT, INSERT ON Persona          TO vendedor;
GRANT SELECT, INSERT ON Telefono_persona TO vendedor;
GRANT SELECT, INSERT ON Cliente          TO vendedor;
GRANT SELECT, INSERT ON Venta            TO vendedor;
GRANT SELECT, INSERT ON Venta_Lote       TO vendedor;

-- 10. Secuencias: quien inserta necesita SELECT en ellas para usar NEXTVAL.
--     Se ignora ORA-00942 si alguna secuencia todavia no existe (se crean en 03_paquetes.sql).
BEGIN
  FOR s IN (SELECT column_value AS secuencia FROM TABLE(sys.odcivarchar2list(
              'SEQ_PERSONA','SEQ_MEDICAMENTO','SEQ_PROVEEDOR','SEQ_LOTE','SEQ_VENTA'))) LOOP
    FOR r IN (SELECT column_value AS rol FROM TABLE(sys.odcivarchar2list(
                'ADMIN_FARMACIA','GERENCIA','ADMINISTRADOR_SUCURSAL','REGENTE','VENDEDOR'))) LOOP
      BEGIN
        EXECUTE IMMEDIATE 'GRANT SELECT ON ' || s.secuencia || ' TO ' || r.rol;
      EXCEPTION WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
      END;
    END LOOP;
  END LOOP;
END;
/

-- 11. (OPCIONAL) Usuarios de ejemplo para iniciar sesion en la aplicacion con Oracle
--     Si ya existen se ignora ORA-01920.
BEGIN
  EXECUTE IMMEDIATE 'CREATE USER ora_vendedor IDENTIFIED BY "vendedor123"';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -1920 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'CREATE USER ora_regente IDENTIFIED BY "regente123"';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -1920 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'CREATE USER ora_gerente IDENTIFIED BY "gerente123"';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -1920 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'CREATE USER ora_admin_suc IDENTIFIED BY "adminsuc123"';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -1920 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'CREATE USER ora_auditor IDENTIFIED BY "auditor123"';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -1920 THEN RAISE; END IF;
END;
/
GRANT vendedor               TO ora_vendedor;
GRANT regente                TO ora_regente;
GRANT gerencia               TO ora_gerente;
GRANT administrador_sucursal TO ora_admin_suc;
GRANT auditor                TO ora_auditor;

-- 12. Comprobar lo que quedo para vendedor
SELECT privilege FROM dba_sys_privs WHERE grantee = 'VENDEDOR';
SELECT table_name, privilege FROM dba_tab_privs WHERE grantee = 'VENDEDOR' ORDER BY table_name, privilege;
SELECT grantee, granted_role FROM dba_role_privs WHERE granted_role IN
  ('ADMIN_FARMACIA','GERENCIA','ADMINISTRADOR_SUCURSAL','REGENTE','VENDEDOR','AUDITOR') ORDER BY 2, 1;

-- Para darle un rol a otro usuario de Oracle:   GRANT vendedor TO nombre_usuario;
-- Para quitarlo:                                REVOKE vendedor FROM nombre_usuario;
-- Si un usuario directo no ve las tablas, que ejecute:  ALTER SESSION SET CURRENT_SCHEMA = farmacia;
