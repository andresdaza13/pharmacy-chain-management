DECLARE
  -- =====================================================================
  -- 05_usuario_empleado   (version para DBeaver, generada desde el script original)
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
      USING '05_usuario_empleado', p_paso, p_estado, SUBSTR(p_detalle, 1, 900);
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

  paso(1, 'CREATE TABLE usuario_empleado ( username VARCHAR2(128) PRIMARY KEY, id_empleado NUMBER NOT', q'~CREATE TABLE usuario_empleado (
    username     VARCHAR2(128) PRIMARY KEY,
    id_empleado  NUMBER NOT NULL REFERENCES Empleado(id_empleado)
)~');

  -- Resumen: objetos que hayan quedado invalidos
  FOR o IN (SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID' ORDER BY 1, 2) LOOP
    v_error := v_error + 1;
    anotar(0, 'INVALIDO', o.object_type || ' ' || o.object_name || ' (ver: SELECT * FROM user_errors)');
  END LOOP;
  anotar(0, 'RESUMEN', v_ok || ' ok, ' || v_existia || ' ya existian u omitidos, ' || v_error || ' con error');
  COMMIT;
END;
