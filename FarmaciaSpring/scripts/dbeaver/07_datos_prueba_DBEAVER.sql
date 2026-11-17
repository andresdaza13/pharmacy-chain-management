DECLARE
  -- =====================================================================
  -- 07_datos_prueba   (DBeaver: Ctrl+A y luego Ctrl+Enter)
  -- Inserta datos de ejemplo USANDO LOS PAQUETES (no INSERT directos), asi tambien
  -- se prueban pkg_personas, pkg_mantenimiento, pkg_inventario y pkg_ventas con sus triggers.
  -- Si algo falla, Oracle deshace TODO (el bloque es una sola sentencia).
  -- Resultado: SELECT * FROM instalacion_log WHERE script = '07_datos_prueba';
  -- =====================================================================
  v_ciudad      NUMBER;
  v_centro      NUMBER;
  v_norte       NUMBER;
  v_cat_analg   NUMBER;
  v_cat_antib   NUMBER;
  v_cat_antih   NUMBER;
  v_cat_cardio  NUMBER;
  v_laura       NUMBER;   -- vendedor, Centro
  v_andres      NUMBER;   -- regente,  Centro
  v_carlos      NUMBER;   -- vendedor, Norte
  v_sofia       NUMBER;   -- regente,  Norte
  v_cli1        NUMBER;
  v_cli2        NUMBER;
  v_cli3        NUMBER;
  v_prov1       NUMBER;
  v_prov2       NUMBER;
  v_acetam      NUMBER;
  v_ibupro      NUMBER;
  v_lorata      NUMBER;
  v_amoxi       NUMBER;
  v_losar       NUMBER;
  v_lote        NUMBER;
  v_venta       NUMBER;
  v_n           NUMBER;

  -- TRUE si la columna se llena sola (IDENTITY)
  FUNCTION es_identity(p_tabla VARCHAR2, p_col VARCHAR2) RETURN BOOLEAN IS
    v NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v FROM user_tab_identity_cols WHERE table_name = p_tabla AND column_name = p_col;
    RETURN v > 0;
  END;

  -- Inserta (id, columnas...) sirviendo tanto si el id es IDENTITY como si no.
  -- Se usa SQL dinamico porque insertar un id en una columna IDENTITY ALWAYS ni siquiera compila.
  FUNCTION insertar(p_tabla VARCHAR2, p_col_id VARCHAR2, p_cols VARCHAR2, p_vals VARCHAR2) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    IF es_identity(p_tabla, p_col_id) THEN
      EXECUTE IMMEDIATE 'INSERT INTO ' || p_tabla || ' (' || p_cols || ') VALUES (' || p_vals || ')'
                        || ' RETURNING ' || p_col_id || ' INTO :1' RETURNING INTO v_id;
    ELSE
      EXECUTE IMMEDIATE 'SELECT NVL(MAX(' || p_col_id || '), 0) + 1 FROM ' || p_tabla INTO v_id;
      EXECUTE IMMEDIATE 'INSERT INTO ' || p_tabla || ' (' || p_col_id || ', ' || p_cols || ') VALUES ('
                        || v_id || ', ' || p_vals || ')';
    END IF;
    RETURN v_id;
  END;

  PROCEDURE anotar(p_msg VARCHAR2) IS
  BEGIN
    INSERT INTO instalacion_log (script, paso, estado, detalle) VALUES ('07_datos_prueba', 0, 'OK', p_msg);
    DBMS_OUTPUT.PUT_LINE(p_msg);
  END;
BEGIN
  -- No duplicar si ya se ejecuto (los documentos son UNIQUE)
  SELECT COUNT(*) INTO v_n FROM Persona WHERE documento = '1061000001';
  IF v_n > 0 THEN
    RAISE_APPLICATION_ERROR(-20099, 'Los datos de prueba ya estaban cargados.');
  END IF;

  -- ---------- Ciudad, sucursales y categorias ----------
  SELECT MIN(id_ciudad) INTO v_ciudad FROM Ciudad;          -- si ya hay una ciudad, se reutiliza
  IF v_ciudad IS NULL THEN
    v_ciudad := insertar('CIUDAD', 'ID_CIUDAD', 'nombre', q'['Popayan']');
  END IF;
  v_centro := insertar('SUCURSAL', 'ID_SUCURSAL', 'nombre, direccion, id_ciudad',
                       q'['Sucursal Centro', 'Calle 5 # 6-20', ]' || v_ciudad);
  v_norte  := insertar('SUCURSAL', 'ID_SUCURSAL', 'nombre, direccion, id_ciudad',
                       q'['Sucursal Norte', 'Carrera 9 # 60N-15', ]' || v_ciudad);
  anotar('Sucursales: Centro=' || v_centro || ', Norte=' || v_norte);

  v_cat_analg  := insertar('CATEGORIA', 'ID_CATEGORIA', 'descripcion', q'['Analgesicos']');
  v_cat_antib  := insertar('CATEGORIA', 'ID_CATEGORIA', 'descripcion', q'['Antibioticos']');
  v_cat_antih  := insertar('CATEGORIA', 'ID_CATEGORIA', 'descripcion', q'['Antihistaminicos']');
  v_cat_cardio := insertar('CATEGORIA', 'ID_CATEGORIA', 'descripcion', q'['Antihipertensivos']');

  -- ---------- Empleados y clientes (pkg_personas del equipo) ----------
  pkg_personas.registrar_persona(p_tipo => 'E', p_nombre => 'Laura', p_apellido => 'Gomez',
      p_documento => '1061000001', p_email => 'laura@farmacia.co', p_telefono => '3001110001',
      p_cargo => 'VENDEDOR', p_salario => 1800000, p_id_sucursal => v_centro, p_id_persona => v_laura);
  pkg_personas.registrar_persona(p_tipo => 'E', p_nombre => 'Andres', p_apellido => 'Ruiz',
      p_documento => '1061000002', p_email => 'andres@farmacia.co', p_telefono => '3001110002',
      p_cargo => 'REGENTE', p_salario => 3200000, p_id_sucursal => v_centro, p_id_persona => v_andres);
  pkg_personas.registrar_persona(p_tipo => 'E', p_nombre => 'Carlos', p_apellido => 'Mena',
      p_documento => '1061000003', p_email => 'carlos@farmacia.co', p_telefono => '3001110003',
      p_cargo => 'VENDEDOR', p_salario => 1800000, p_id_sucursal => v_norte, p_id_persona => v_carlos);
  pkg_personas.registrar_persona(p_tipo => 'E', p_nombre => 'Sofia', p_apellido => 'Lopez',
      p_documento => '1061000004', p_email => 'sofia@farmacia.co', p_telefono => '3001110004',
      p_cargo => 'REGENTE', p_salario => 3200000, p_id_sucursal => v_norte, p_id_persona => v_sofia);
  anotar('Empleados: Laura(vendedor)=' || v_laura || ', Andres(regente)=' || v_andres
      || ', Carlos(vendedor)=' || v_carlos || ', Sofia(regente)=' || v_sofia);

  pkg_personas.registrar_persona(p_tipo => 'C', p_nombre => 'Maria', p_apellido => 'Torres',
      p_documento => '1061000101', p_email => 'maria@correo.co', p_telefono => '3102220001',
      p_direccion => 'Barrio Bolivar', p_id_persona => v_cli1);
  pkg_personas.registrar_persona(p_tipo => 'C', p_nombre => 'Jorge', p_apellido => 'Paz',
      p_documento => '1061000102', p_email => 'jorge@correo.co', p_telefono => '3102220002',
      p_direccion => 'Barrio La Esmeralda', p_id_persona => v_cli2);
  pkg_personas.registrar_persona(p_tipo => 'C', p_nombre => 'Ana', p_apellido => 'Velasco',
      p_documento => '1061000103', p_email => 'ana@correo.co', p_telefono => '3102220003',
      p_direccion => 'Barrio Modelo', p_id_persona => v_cli3);

  -- ---------- Proveedores (pkg_mantenimiento) ----------
  pkg_mantenimiento.crear_proveedor('900123456-1', 'Drogueria Mayorista del Cauca', 'Zona Industrial', v_prov1);
  pkg_mantenimiento.crear_proveedor('900654321-2', 'Laboratorios Andinos SAS', 'Cali, Valle', v_prov2);

  -- ---------- Medicamentos (pkg_inventario) ----------
  pkg_inventario.crear_medicamento('Dolex', 'Acetaminofen', 'Tabletas 500 mg x 10', v_cat_analg, 4500, 'N', v_acetam);
  pkg_inventario.crear_medicamento('Advil', 'Ibuprofeno', 'Capsulas 400 mg x 10', v_cat_analg, 8900, 'N', v_ibupro);
  pkg_inventario.crear_medicamento('Clarityne', 'Loratadina', 'Tabletas 10 mg x 10', v_cat_antih, 12500, 'N', v_lorata);
  pkg_inventario.crear_medicamento('Amoxal', 'Amoxicilina', 'Capsulas 500 mg x 21', v_cat_antib, 18000, 'S', v_amoxi);
  pkg_inventario.crear_medicamento('Cozaar', 'Losartan', 'Tabletas 50 mg x 30', v_cat_cardio, 25000, 'S', v_losar);

  -- ---------- Lotes (pkg_inventario.registrar_lote): estados distintos para los reportes ----------
  -- Centro (los registra el regente Andres)
  pkg_inventario.registrar_lote(v_acetam, v_centro, v_prov1, v_andres, SYSDATE - 200, SYSDATE + 15,  40, v_lote);  -- proximo a vencer
  pkg_inventario.registrar_lote(v_acetam, v_centro, v_prov1, v_andres, SYSDATE - 30,  SYSDATE + 400, 100, v_lote); -- vigente
  pkg_inventario.registrar_lote(v_ibupro, v_centro, v_prov2, v_andres, SYSDATE - 60,  SYSDATE + 300, 60, v_lote);
  pkg_inventario.registrar_lote(v_lorata, v_centro, v_prov2, v_andres, SYSDATE - 90,  SYSDATE + 250, 50, v_lote);
  pkg_inventario.registrar_lote(v_amoxi,  v_centro, v_prov1, v_andres, SYSDATE - 40,  SYSDATE + 200, 30, v_lote);
  pkg_inventario.registrar_lote(v_losar,  v_centro, v_prov2, v_andres, SYSDATE - 400, SYSDATE - 5,   20, v_lote);  -- vencido
  pkg_inventario.registrar_lote(v_losar,  v_centro, v_prov2, v_andres, SYSDATE - 20,  SYSDATE + 500, 45, v_lote);
  -- Norte (los registra la regente Sofia)
  pkg_inventario.registrar_lote(v_acetam, v_norte, v_prov1, v_sofia, SYSDATE - 10, SYSDATE + 365, 80, v_lote);
  pkg_inventario.registrar_lote(v_ibupro, v_norte, v_prov2, v_sofia, SYSDATE - 10, SYSDATE + 20,  25, v_lote);   -- proximo a vencer
  pkg_inventario.registrar_lote(v_amoxi,  v_norte, v_prov1, v_sofia, SYSDATE - 10, SYSDATE + 180, 30, v_lote);
  anotar('Medicamentos y 10 lotes creados (hay vigentes, proximos a vencer y uno vencido)');

  -- ---------- Ventas de ejemplo (pkg_ventas del equipo + sus triggers) ----------
  -- Venta 1: Laura (vendedor) vende 15 Dolex -> FEFO: salen primero del lote que vence en 15 dias
  pkg_ventas.registrar_venta(p_id_cliente => v_cli1, p_id_empleado => v_laura, p_id_sucursal => v_centro,
                             p_metodo_pago => 'EFECTIVO', p_id_venta => v_venta);
  pkg_ventas.agregar_medicamento(v_venta, v_acetam, 15);
  pkg_ventas.agregar_medicamento(v_venta, v_ibupro, 2);
  anotar('Venta ' || v_venta || ': Dolex x15 + Advil x2 (Centro, EFECTIVO)');

  -- Venta 2: Andres (regente) vende amoxicilina CON receta
  pkg_ventas.registrar_venta(p_id_cliente => v_cli2, p_id_empleado => v_andres, p_id_sucursal => v_centro,
                             p_metodo_pago => 'TARJETA', p_nombre_medico => 'Dr. Felipe Zuniga',
                             p_registro_medico => 'RM-45821', p_id_venta => v_venta);
  pkg_ventas.agregar_medicamento(v_venta, v_amoxi, 1);
  anotar('Venta ' || v_venta || ': Amoxal x1 con receta (Centro, TARJETA)');

  -- Venta 3: Carlos (vendedor) en Norte
  pkg_ventas.registrar_venta(p_id_cliente => v_cli3, p_id_empleado => v_carlos, p_id_sucursal => v_norte,
                             p_metodo_pago => 'EFECTIVO', p_id_venta => v_venta);
  pkg_ventas.agregar_medicamento(v_venta, v_acetam, 3);
  anotar('Venta ' || v_venta || ': Dolex x3 (Norte)');

  -- ---------- Usuarios de Oracle -> empleados (para iniciar sesion en la app) ----------
  MERGE INTO usuario_empleado u
  USING (SELECT 'ORA_VENDEDOR' username, v_laura id_empleado FROM dual
         UNION ALL SELECT 'ORA_REGENTE', v_andres FROM dual) d
     ON (u.username = d.username)
   WHEN MATCHED THEN UPDATE SET u.id_empleado = d.id_empleado
   WHEN NOT MATCHED THEN INSERT (username, id_empleado) VALUES (d.username, d.id_empleado);
  anotar('ora_vendedor -> Laura (Centro) | ora_regente -> Andres (Centro)');

  COMMIT;
  anotar('LISTO: datos de prueba cargados');
END;
