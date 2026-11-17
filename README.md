# Farmacia — Cadena de farmacias (Bases de Datos II)

Ventas, inventario por **lotes** (FEFO), recetas médicas, reportes y seis roles.
Spring Boot 3 + Lombok + Oracle (paquetes, funciones, **triggers** y vistas) + interfaz estilo Apple que
funciona en **PC (app de escritorio JavaFX)**, **celular (PWA instalable)** y navegador.

```
farmacia/
├── FarmaciaSpring/        ← servidor Spring Boot (MVC + Thymeleaf) — lo que abres en NetBeans
│   └── scripts/           ← SQL: 03 paquetes · 04 roles · 05 usuario↔empleado · 06 LÓGICA (nuevo)
├── FarmaciaEscritorio/    ← app de escritorio JavaFX (ventana nativa para el PC)
├── deploy/                ← Docker Compose: Oracle + app + Caddy (HTTPS) para la nube
└── .github/workflows/     ← GitHub Actions: compila el .jar y crea el ejecutable de escritorio
```

## 1. Arquitectura (cómo se reparte el trabajo)

```
 Celular (PWA) ─┐
 Navegador ─────┼──HTTPS──► Spring Boot ──JDBC──► Oracle
 PC (JavaFX) ───┘           │                       │
                            │ controller  (rutas)   │ pkg_farmacia   (procedimientos)
                            │ service     (reglas)  │ fn_*           (funciones)
                            │ repository  (SQL)     │ trg_*          (disparadores)
                            │ despacho    (whitelist│ vw_rep_*       (vistas de reportes)
                            │              + roles) │ roles Oracle   (04_roles.sql)
```

**Tres barreras de seguridad / reglas**

| Capa | Archivo | Qué protege |
|---|---|---|
| 1. URL | `SeguridadConfig.java` | Qué rol entra a qué pantalla |
| 2. Operación | `Operacion.java` + `DespachadorProcedimientos.java` | Qué rol ejecuta qué procedimiento (whitelist, evita inyección SQL) |
| 3. Datos | `06_logica_negocio.sql` (triggers) | Las reglas del negocio, venga el INSERT de donde venga |

## 2. Lo que se implementó del documento del proyecto

La base FARMACIA_APP ya traía lógica del equipo; la app la **reutiliza** en vez de duplicarla.

| Pide el documento | Dónde está | Autor |
|---|---|---|
| `registrar_persona` + exclusividad Cliente/Empleado | `pkg_personas` + FK compuesta `(id, tipo_persona)` y CHECK `'C'/'E'` | equipo |
| `registrar_venta` (FEFO, empleado de la sucursal, receta) | `pkg_ventas.registrar_venta` + `agregar_medicamento`, triggers `trg_venta_bi`, `trg_venta_lote_bi` | equipo |
| Descontar stock y sumar total | `trg_venta_lote_ai` | equipo |
| Detalle de venta inmutable | `trg_venta_lote_inmutable` | equipo |
| `anular_venta` (repone stock, estado ANULADA) | `pkg_ventas.anular_venta` | equipo |
| `fn_total_venta` | `pkg_ventas.fn_total_venta` | equipo |
| `registrar_lote` | `pkg_inventario.registrar_lote` (03) | nuevo |
| `fn_dias_para_vencer`, `fn_estado_lote`, `fn_stock_medicamento` | 06 | nuevo |
| Venta anulada no se reactiva | `trg_venta_estado_bu` (06) | nuevo |
| Auditoría de precios | `trg_medicamento_auditoria` → `Auditoria_Precio` (06) | nuevo |
| 5 reportes | vistas `vw_rep_*` (06) → pantalla **Reportes** | nuevo |
| 6 roles | `04_roles.sql` + `Rol.java` | nuevo |

### Requisitos de la profesora (documento "Entregas proyecto final")

| Entrega | Requisito | Dónde |
|---|---|---|
| 2 | DDL, datos de prueba, roles y privilegios | DDL del equipo · `07_datos_prueba.sql` · `04_roles.sql` |
| 3 | Paquetes CRUD (insertar, modificar, eliminar) | `pkg_personas`, `pkg_ventas` (equipo) · `pkg_inventario`, `pkg_mantenimiento` (03) · `pkg_sucursales` (08) |
| 3 | Disparadores que incrementan secuencias de columnas código | `trg_<tabla>_id` + `seq_<tabla>` · `trg_venta_codigo` → `codigo_factura` FV-AAAA-000001 (08) |
| 4 | Registros y colecciones | `pkg_reportes`: RECORD, tabla anidada pública `g_resumen`, `%ROWTYPE`, arreglo asociativo, BULK COLLECT, función PIPELINED (08) |
| 5 | Cursores simples y parametrizados | `pkg_reportes.listar_medicamentos_agotados` (OPEN/FETCH/CLOSE) · `listar_lotes_por_vencer(p_sucursal, p_dias)` · `pkg_ventas.agregar_medicamento` (equipo) |
| 6 | Disparadores básicos, INSTEAD OF y compuestos | básicos: `trg_venta_bi`, `trg_venta_lote_*` (equipo), `trg_venta_estado_bu` · INSTEAD OF: `trg_pacientes_instead` sobre `vw_pacientes` · compuesto: `trg_medicamento_precio` |
| 7 | Transacciones explícitas | `pkg_traslados.trasladar_stock`: SAVEPOINT / COMMIT / ROLLBACK TO (08) |
| 8 | Índice básico y basado en función, monitoreo | `idx_lote_med_suc_venc` · `idx_venta_dia` (TRUNC) · `idx_persona_apellido_upper` (UPPER) · MONITORING USAGE |
| 8 | Diccionario de datos y plan de ejecución | `dbeaver/09_diccionario_y_plan.sql` |
| II.4 | Bloques anónimos de prueba | `dbeaver/10_pruebas_bloques_anonimos.sql` |

Scripts para DBeaver (un solo bloque, sin `/`): `FarmaciaSpring/scripts/dbeaver/`. Se ejecutan con **Ctrl+A** y
**Ctrl+Enter**; el resultado queda en `SELECT * FROM instalacion_log ORDER BY id;`.

## 3. Ejecutar en tu PC (desarrollo)

1. **Oracle**: con la conexión `farmacia` (XEPDB1) ejecuta con **F5 (Run Script)** en este orden:
   tus scripts de tablas (00–02) → `03_paquetes.sql` → `04_roles.sql` → `05_usuario_empleado.sql` → **`06_logica_negocio.sql`**.
   Al final de 06 debe salir todo `VALID`.
2. Liga los usuarios con empleados (ver `05_usuario_empleado.sql`), p. ej.
   `INSERT INTO usuario_empleado VALUES ('ORA_VENDEDOR', 1); COMMIT;`
   El empleado debe tener cargo *vendedor* o *regente* para poder vender (lo exige el trigger).
3. **NetBeans**: *File › Open Project* › `FarmaciaSpring` › clic derecho en `FarmaciaApplication` › *Run File*.
   Lombok: NetBeans lo detecta solo por el `pom.xml` (si marca errores en rojo, *Clean and Build*).
4. Abre <http://localhost:8080> e ingresa con un usuario de Oracle (`ora_vendedor / vendedor123`, `ora_regente / regente123`, …).

Usuarios de ejemplo (04_roles.sql): `ora_vendedor`, `ora_regente`, `ora_gerente`, `ora_admin_suc`, `ora_auditor`.
Tu usuario `farmacia` (DBA) entra como Administrador.

## 4. App de escritorio para el PC (JavaFX)

Es una **ventana nativa de Java** con un `WebView` que muestra la misma interfaz.
Tiene dos modos (se eligen la primera vez; luego `Ctrl+,`):

- **Nube**: se conecta a tu servidor desplegado (la misma dirección que en el celular).
- **Local**: arranca `farmacia.jar` en tu PC (con tu Oracle local) y abre `http://localhost:8080`.

Probarla desde NetBeans: abre `FarmaciaEscritorio` › *Run Maven › Goals* › `javafx:run`.

Crear el ejecutable **sin instalar nada**: sube el repo a GitHub › pestaña **Actions** › *Escritorio (JavaFX + jpackage)* ›
*Run workflow*. Descarga `Farmacia-Windows.zip`, descomprime y abre `Farmacia.exe` (trae su propio Java).
Si creas una etiqueta (`git tag v1.0.0 && git push --tags`) se publica en **Releases**.

## 5. Desplegar gratis (celular + PC desde cualquier lugar)

GitHub guarda el código y compila, pero **no puede ejecutar** un servidor Java con Oracle
(GitHub Pages solo sirve archivos estáticos). La opción gratuita que sí corre Oracle es:

**Oracle Cloud Free Tier** (VM Ampere A1 *Always Free*, hoy 2 OCPU / 12 GB) + **DuckDNS** (dominio gratis) + **Caddy** (HTTPS gratis).

1. Crea la cuenta en Oracle Cloud y una instancia **VM.Standard.A1.Flex** (2 OCPU, 12 GB) con Ubuntu.
   En la *Security List* de la VCN abre los puertos **80** y **443**. En la VM: `sudo iptables -I INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT`.
2. En <https://www.duckdns.org> crea `mifarmacia.duckdns.org` apuntando a la IP pública de la VM.
3. En la VM:
   ```bash
   sudo apt update && sudo apt install -y docker.io docker-compose-v2 git
   git clone https://github.com/TU_USUARIO/farmacia.git && cd farmacia
   cp TUS_SCRIPTS_DE_TABLAS/*.sql FarmaciaSpring/scripts/   # 00_..., 01_..., 02_... (antes que el 03)
   cd deploy && cp .env.example .env && nano .env            # dominio y claves
   sudo docker compose up -d --build
   sudo docker compose logs -f oracle                        # espera "DATABASE IS READY TO USE!"
   ```
4. Abre `https://mifarmacia.duckdns.org`.
   - **iPhone**: Safari › Compartir › *Agregar a pantalla de inicio*.
   - **Android**: Chrome › menú › *Instalar app*.
   - **PC**: la app JavaFX en modo *Nube* (o Chrome/Edge › *Instalar Farmacia*).

> La PWA necesita **HTTPS** para instalarse; por eso va Caddy. En `http://IP:8080` la web funciona pero no se instala.

## 6. Conceptos que conviene saber explicar en la sustentación

- **Lombok**: `@Data` (DTO), `@RequiredArgsConstructor` (inyección por constructor de los campos `final`), `@Getter`.
  Los `record` de Java ya generan constructor y getters: por eso los modelos de lectura no usan Lombok.
- **Colecciones en PL/SQL**: `registrar_venta` recibe todas las líneas en `SYS.ODCINUMBERLIST`;
  Java las envía con `OracleConnection.createOracleArray(...)` (ver `DespachadorProcedimientos.asignar`).
- **FEFO** (*First Expired, First Out*): el cursor de `registrar_venta` ordena por `fecha_vencimiento` y usa `FOR UPDATE`
  para que dos ventas simultáneas no gasten el mismo stock.
- **Tabla mutante (ORA-04091)**: los triggers de `Venta_Lote` consultan *otras* tablas (Lote, Venta), nunca la propia.
- **Atomicidad**: si `registrar_venta` lanza `RAISE_APPLICATION_ERROR`, Oracle deshace todo lo que hizo esa llamada;
  además el servicio Java es `@Transactional`.
- **Errores propios -20001..-20099**: `MensajesBd.java` muestra al usuario el texto del `RAISE_APPLICATION_ERROR`.
