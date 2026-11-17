DECLARE
  -- =====================================================================
  -- 04_roles   (version para DBeaver, generada desde el script original)
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
      USING '04_roles', p_paso, p_estado, SUBSTR(p_detalle, 1, 900);
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

  paso(1, 'BEGIN FOR r IN (SELECT column_value AS nombre FROM TABLE(sys.odcivarchar2list( ''ADMIN_FARM', q'~BEGIN
  FOR r IN (SELECT column_value AS nombre FROM TABLE(sys.odcivarchar2list(
              'ADMIN_FARMACIA','GERENCIA','ADMINISTRADOR_SUCURSAL','REGENTE','VENDEDOR','AUDITOR'))) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'CREATE ROLE ' || r.nombre;
    EXCEPTION WHEN OTHERS THEN
      IF SQLCODE != -1921 THEN RAISE; END IF;
    END;
  END LOOP;
END;~');
  paso(2, 'DECLARE v_total NUMBER; BEGIN SELECT COUNT(*) INTO v_total FROM dba_roles WHERE role IN (''', q'~DECLARE
  v_total NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_total FROM dba_roles
   WHERE role IN ('ADMIN_FARMACIA','GERENCIA','ADMINISTRADOR_SUCURSAL','REGENTE','VENDEDOR','AUDITOR');
  IF v_total < 6 THEN
    RAISE_APPLICATION_ERROR(-20001,
      'Solo existen ' || v_total || ' de 6 roles. Revisa si hay un USUARIO con el mismo nombre que un rol.');
  END IF;
END;~');
  paso(3, 'GRANT CREATE SESSION TO admin_farmacia', q'~GRANT CREATE SESSION TO admin_farmacia~');
  paso(4, 'GRANT CREATE SESSION TO gerencia', q'~GRANT CREATE SESSION TO gerencia~');
  paso(5, 'GRANT CREATE SESSION TO administrador_sucursal', q'~GRANT CREATE SESSION TO administrador_sucursal~');
  paso(6, 'GRANT CREATE SESSION TO regente', q'~GRANT CREATE SESSION TO regente~');
  paso(7, 'GRANT CREATE SESSION TO vendedor', q'~GRANT CREATE SESSION TO vendedor~');
  paso(8, 'GRANT CREATE SESSION TO auditor', q'~GRANT CREATE SESSION TO auditor~');
  paso(9, 'GRANT ALL ON Persona TO admin_farmacia', q'~GRANT ALL ON Persona            TO admin_farmacia~');
  paso(10, 'GRANT ALL ON Telefono_persona TO admin_farmacia', q'~GRANT ALL ON Telefono_persona   TO admin_farmacia~');
  paso(11, 'GRANT ALL ON Cliente TO admin_farmacia', q'~GRANT ALL ON Cliente            TO admin_farmacia~');
  paso(12, 'GRANT ALL ON Ciudad TO admin_farmacia', q'~GRANT ALL ON Ciudad             TO admin_farmacia~');
  paso(13, 'GRANT ALL ON Sucursal TO admin_farmacia', q'~GRANT ALL ON Sucursal           TO admin_farmacia~');
  paso(14, 'GRANT ALL ON Telefono_Sucursal TO admin_farmacia', q'~GRANT ALL ON Telefono_Sucursal  TO admin_farmacia~');
  paso(15, 'GRANT ALL ON Empleado TO admin_farmacia', q'~GRANT ALL ON Empleado           TO admin_farmacia~');
  paso(16, 'GRANT ALL ON Categoria TO admin_farmacia', q'~GRANT ALL ON Categoria          TO admin_farmacia~');
  paso(17, 'GRANT ALL ON Medicamento TO admin_farmacia', q'~GRANT ALL ON Medicamento        TO admin_farmacia~');
  paso(18, 'GRANT ALL ON Proveedor TO admin_farmacia', q'~GRANT ALL ON Proveedor          TO admin_farmacia~');
  paso(19, 'GRANT ALL ON Telefono TO admin_farmacia', q'~GRANT ALL ON Telefono           TO admin_farmacia~');
  paso(20, 'GRANT ALL ON Lote TO admin_farmacia', q'~GRANT ALL ON Lote               TO admin_farmacia~');
  paso(21, 'GRANT ALL ON Venta TO admin_farmacia', q'~GRANT ALL ON Venta              TO admin_farmacia~');
  paso(22, 'GRANT ALL ON Venta_Lote TO admin_farmacia', q'~GRANT ALL ON Venta_Lote         TO admin_farmacia~');
  paso(23, 'GRANT SELECT ON Persona TO auditor', q'~GRANT SELECT ON Persona            TO auditor~');
  paso(24, 'GRANT SELECT ON Telefono_persona TO auditor', q'~GRANT SELECT ON Telefono_persona   TO auditor~');
  paso(25, 'GRANT SELECT ON Cliente TO auditor', q'~GRANT SELECT ON Cliente            TO auditor~');
  paso(26, 'GRANT SELECT ON Ciudad TO auditor', q'~GRANT SELECT ON Ciudad             TO auditor~');
  paso(27, 'GRANT SELECT ON Sucursal TO auditor', q'~GRANT SELECT ON Sucursal           TO auditor~');
  paso(28, 'GRANT SELECT ON Telefono_Sucursal TO auditor', q'~GRANT SELECT ON Telefono_Sucursal  TO auditor~');
  paso(29, 'GRANT SELECT ON Empleado TO auditor', q'~GRANT SELECT ON Empleado           TO auditor~');
  paso(30, 'GRANT SELECT ON Categoria TO auditor', q'~GRANT SELECT ON Categoria          TO auditor~');
  paso(31, 'GRANT SELECT ON Medicamento TO auditor', q'~GRANT SELECT ON Medicamento        TO auditor~');
  paso(32, 'GRANT SELECT ON Proveedor TO auditor', q'~GRANT SELECT ON Proveedor          TO auditor~');
  paso(33, 'GRANT SELECT ON Telefono TO auditor', q'~GRANT SELECT ON Telefono           TO auditor~');
  paso(34, 'GRANT SELECT ON Lote TO auditor', q'~GRANT SELECT ON Lote               TO auditor~');
  paso(35, 'GRANT SELECT ON Venta TO auditor', q'~GRANT SELECT ON Venta              TO auditor~');
  paso(36, 'GRANT SELECT ON Venta_Lote TO auditor', q'~GRANT SELECT ON Venta_Lote         TO auditor~');
  paso(37, 'GRANT SELECT ON Persona TO gerencia', q'~GRANT SELECT ON Persona            TO gerencia~');
  paso(38, 'GRANT SELECT ON Telefono_persona TO gerencia', q'~GRANT SELECT ON Telefono_persona   TO gerencia~');
  paso(39, 'GRANT SELECT ON Cliente TO gerencia', q'~GRANT SELECT ON Cliente            TO gerencia~');
  paso(40, 'GRANT SELECT ON Ciudad TO gerencia', q'~GRANT SELECT ON Ciudad             TO gerencia~');
  paso(41, 'GRANT SELECT ON Sucursal TO gerencia', q'~GRANT SELECT ON Sucursal           TO gerencia~');
  paso(42, 'GRANT SELECT ON Telefono_Sucursal TO gerencia', q'~GRANT SELECT ON Telefono_Sucursal  TO gerencia~');
  paso(43, 'GRANT SELECT ON Empleado TO gerencia', q'~GRANT SELECT ON Empleado           TO gerencia~');
  paso(44, 'GRANT SELECT ON Lote TO gerencia', q'~GRANT SELECT ON Lote               TO gerencia~');
  paso(45, 'GRANT SELECT ON Venta TO gerencia', q'~GRANT SELECT ON Venta              TO gerencia~');
  paso(46, 'GRANT SELECT ON Venta_Lote TO gerencia', q'~GRANT SELECT ON Venta_Lote         TO gerencia~');
  paso(47, 'GRANT SELECT, INSERT, UPDATE ON Categoria TO gerencia', q'~GRANT SELECT, INSERT, UPDATE ON Categoria   TO gerencia~');
  paso(48, 'GRANT SELECT, INSERT, UPDATE ON Medicamento TO gerencia', q'~GRANT SELECT, INSERT, UPDATE ON Medicamento TO gerencia~');
  paso(49, 'GRANT SELECT, INSERT, UPDATE ON Proveedor TO gerencia', q'~GRANT SELECT, INSERT, UPDATE ON Proveedor   TO gerencia~');
  paso(50, 'GRANT SELECT, INSERT, UPDATE ON Telefono TO gerencia', q'~GRANT SELECT, INSERT, UPDATE ON Telefono    TO gerencia~');
  paso(51, 'GRANT SELECT ON Cliente TO administrador_sucursal', q'~GRANT SELECT ON Cliente            TO administrador_sucursal~');
  paso(52, 'GRANT SELECT ON Ciudad TO administrador_sucursal', q'~GRANT SELECT ON Ciudad             TO administrador_sucursal~');
  paso(53, 'GRANT SELECT ON Sucursal TO administrador_sucursal', q'~GRANT SELECT ON Sucursal           TO administrador_sucursal~');
  paso(54, 'GRANT SELECT ON Telefono_Sucursal TO administrador_sucursal', q'~GRANT SELECT ON Telefono_Sucursal  TO administrador_sucursal~');
  paso(55, 'GRANT SELECT ON Categoria TO administrador_sucursal', q'~GRANT SELECT ON Categoria          TO administrador_sucursal~');
  paso(56, 'GRANT SELECT ON Medicamento TO administrador_sucursal', q'~GRANT SELECT ON Medicamento        TO administrador_sucursal~');
  paso(57, 'GRANT SELECT ON Proveedor TO administrador_sucursal', q'~GRANT SELECT ON Proveedor          TO administrador_sucursal~');
  paso(58, 'GRANT SELECT ON Telefono TO administrador_sucursal', q'~GRANT SELECT ON Telefono           TO administrador_sucursal~');
  paso(59, 'GRANT SELECT ON Venta TO administrador_sucursal', q'~GRANT SELECT ON Venta              TO administrador_sucursal~');
  paso(60, 'GRANT SELECT ON Venta_Lote TO administrador_sucursal', q'~GRANT SELECT ON Venta_Lote         TO administrador_sucursal~');
  paso(61, 'GRANT SELECT, INSERT, UPDATE ON Persona TO administrador_sucursal', q'~GRANT SELECT, INSERT, UPDATE ON Persona          TO administrador_sucursal~');
  paso(62, 'GRANT SELECT, INSERT, UPDATE ON Telefono_persona TO administrador_sucursal', q'~GRANT SELECT, INSERT, UPDATE ON Telefono_persona TO administrador_sucursal~');
  paso(63, 'GRANT SELECT, INSERT, UPDATE ON Empleado TO administrador_sucursal', q'~GRANT SELECT, INSERT, UPDATE ON Empleado         TO administrador_sucursal~');
  paso(64, 'GRANT SELECT, INSERT, UPDATE ON Lote TO administrador_sucursal', q'~GRANT SELECT, INSERT, UPDATE ON Lote             TO administrador_sucursal~');
  paso(65, 'GRANT SELECT ON Ciudad TO regente', q'~GRANT SELECT ON Ciudad             TO regente~');
  paso(66, 'GRANT SELECT ON Sucursal TO regente', q'~GRANT SELECT ON Sucursal           TO regente~');
  paso(67, 'GRANT SELECT ON Telefono_Sucursal TO regente', q'~GRANT SELECT ON Telefono_Sucursal  TO regente~');
  paso(68, 'GRANT SELECT ON Categoria TO regente', q'~GRANT SELECT ON Categoria          TO regente~');
  paso(69, 'GRANT SELECT, INSERT, UPDATE ON Medicamento TO regente', q'~GRANT SELECT, INSERT, UPDATE ON Medicamento TO regente~');
  paso(70, 'GRANT SELECT, INSERT, UPDATE ON Proveedor TO regente', q'~GRANT SELECT, INSERT, UPDATE ON Proveedor   TO regente~');
  paso(71, 'GRANT SELECT, INSERT, UPDATE ON Telefono TO regente', q'~GRANT SELECT, INSERT, UPDATE ON Telefono    TO regente~');
  paso(72, 'GRANT SELECT, INSERT, UPDATE ON Lote TO regente', q'~GRANT SELECT, INSERT, UPDATE ON Lote        TO regente~');
  paso(73, 'GRANT SELECT, INSERT ON Persona TO regente', q'~GRANT SELECT, INSERT ON Persona          TO regente~');
  paso(74, 'GRANT SELECT, INSERT ON Telefono_persona TO regente', q'~GRANT SELECT, INSERT ON Telefono_persona TO regente~');
  paso(75, 'GRANT SELECT, INSERT ON Cliente TO regente', q'~GRANT SELECT, INSERT ON Cliente          TO regente~');
  paso(76, 'GRANT SELECT, INSERT ON Venta TO regente', q'~GRANT SELECT, INSERT ON Venta            TO regente~');
  paso(77, 'GRANT SELECT, INSERT ON Venta_Lote TO regente', q'~GRANT SELECT, INSERT ON Venta_Lote       TO regente~');
  paso(78, 'GRANT SELECT ON Ciudad TO vendedor', q'~GRANT SELECT ON Ciudad             TO vendedor~');
  paso(79, 'GRANT SELECT ON Sucursal TO vendedor', q'~GRANT SELECT ON Sucursal           TO vendedor~');
  paso(80, 'GRANT SELECT ON Telefono_Sucursal TO vendedor', q'~GRANT SELECT ON Telefono_Sucursal  TO vendedor~');
  paso(81, 'GRANT SELECT ON Categoria TO vendedor', q'~GRANT SELECT ON Categoria          TO vendedor~');
  paso(82, 'GRANT SELECT ON Medicamento TO vendedor', q'~GRANT SELECT ON Medicamento        TO vendedor~');
  paso(83, 'GRANT SELECT ON Lote TO vendedor', q'~GRANT SELECT ON Lote               TO vendedor~');
  paso(84, 'GRANT UPDATE (cantidad_actual) ON Lote TO vendedor', q'~GRANT UPDATE (cantidad_actual) ON Lote TO vendedor~');
  paso(85, 'GRANT SELECT, INSERT ON Persona TO vendedor', q'~GRANT SELECT, INSERT ON Persona          TO vendedor~');
  paso(86, 'GRANT SELECT, INSERT ON Telefono_persona TO vendedor', q'~GRANT SELECT, INSERT ON Telefono_persona TO vendedor~');
  paso(87, 'GRANT SELECT, INSERT ON Cliente TO vendedor', q'~GRANT SELECT, INSERT ON Cliente          TO vendedor~');
  paso(88, 'GRANT SELECT, INSERT ON Venta TO vendedor', q'~GRANT SELECT, INSERT ON Venta            TO vendedor~');
  paso(89, 'GRANT SELECT, INSERT ON Venta_Lote TO vendedor', q'~GRANT SELECT, INSERT ON Venta_Lote       TO vendedor~');
  paso(90, 'BEGIN FOR s IN (SELECT column_value AS secuencia FROM TABLE(sys.odcivarchar2list( ''SEQ_PER', q'~BEGIN
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
END;~');
  paso(91, 'BEGIN EXECUTE IMMEDIATE ''CREATE USER ora_vendedor IDENTIFIED BY "vendedor123"''; EXCEPTION ', q'~BEGIN
  EXECUTE IMMEDIATE 'CREATE USER ora_vendedor IDENTIFIED BY "vendedor123"';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -1920 THEN RAISE; END IF;
END;~');
  paso(92, 'BEGIN EXECUTE IMMEDIATE ''CREATE USER ora_regente IDENTIFIED BY "regente123"''; EXCEPTION WH', q'~BEGIN
  EXECUTE IMMEDIATE 'CREATE USER ora_regente IDENTIFIED BY "regente123"';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -1920 THEN RAISE; END IF;
END;~');
  paso(93, 'BEGIN EXECUTE IMMEDIATE ''CREATE USER ora_gerente IDENTIFIED BY "gerente123"''; EXCEPTION WH', q'~BEGIN
  EXECUTE IMMEDIATE 'CREATE USER ora_gerente IDENTIFIED BY "gerente123"';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -1920 THEN RAISE; END IF;
END;~');
  paso(94, 'BEGIN EXECUTE IMMEDIATE ''CREATE USER ora_admin_suc IDENTIFIED BY "adminsuc123"''; EXCEPTION', q'~BEGIN
  EXECUTE IMMEDIATE 'CREATE USER ora_admin_suc IDENTIFIED BY "adminsuc123"';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -1920 THEN RAISE; END IF;
END;~');
  paso(95, 'BEGIN EXECUTE IMMEDIATE ''CREATE USER ora_auditor IDENTIFIED BY "auditor123"''; EXCEPTION WH', q'~BEGIN
  EXECUTE IMMEDIATE 'CREATE USER ora_auditor IDENTIFIED BY "auditor123"';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -1920 THEN RAISE; END IF;
END;~');
  paso(96, 'GRANT vendedor TO ora_vendedor', q'~GRANT vendedor               TO ora_vendedor~');
  paso(97, 'GRANT regente TO ora_regente', q'~GRANT regente                TO ora_regente~');
  paso(98, 'GRANT gerencia TO ora_gerente', q'~GRANT gerencia               TO ora_gerente~');
  paso(99, 'GRANT administrador_sucursal TO ora_admin_suc', q'~GRANT administrador_sucursal TO ora_admin_suc~');
  paso(100, 'GRANT auditor TO ora_auditor', q'~GRANT auditor                TO ora_auditor~');

  -- Resumen: objetos que hayan quedado invalidos
  FOR o IN (SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID' ORDER BY 1, 2) LOOP
    v_error := v_error + 1;
    anotar(0, 'INVALIDO', o.object_type || ' ' || o.object_name || ' (ver: SELECT * FROM user_errors)');
  END LOOP;
  anotar(0, 'RESUMEN', v_ok || ' ok, ' || v_existia || ' ya existian u omitidos, ' || v_error || ' con error');
  COMMIT;
END;
