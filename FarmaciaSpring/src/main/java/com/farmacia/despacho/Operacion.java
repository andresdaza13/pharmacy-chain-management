package com.farmacia.despacho;

import static com.farmacia.despacho.Rol.*;

/**
 * CATÁLOGO (whitelist) de todo lo que la aplicación puede ejecutar en Oracle.
 * Cada operación dice: qué procedimiento llama, cuántos parámetros de ENTRADA tiene,
 * si devuelve un ID por un parámetro OUT (el último), y qué roles pueden ejecutarla.
 *
 * Paquetes del EQUIPO (ya existían en FARMACIA_APP): pkg_personas, pkg_ventas.
 * Paquetes de 03_paquetes.sql: pkg_inventario, pkg_mantenimiento.
 * Paquetes de 08_requisitos_proyecto.sql: pkg_sucursales, pkg_traslados (pkg_reportes se usa desde SQL).
 */
public enum Operacion {

    // ---- pkg_personas (equipo): Persona + Cliente | Empleado ----
    REGISTRAR_PERSONA("pkg_personas.registrar_persona", 10, true, ADMIN, ADMIN_SUCURSAL, REGENTE, VENDEDOR),

    // ---- pkg_ventas (equipo): la venta se arma en dos pasos dentro de UNA transacción ----
    VENTA_REGISTRAR("pkg_ventas.registrar_venta", 6, true, ADMIN, REGENTE, VENDEDOR),
    VENTA_AGREGAR_MEDICAMENTO("pkg_ventas.agregar_medicamento", 3, false, ADMIN, REGENTE, VENDEDOR),
    VENTA_ANULAR("pkg_ventas.anular_venta", 1, false, ADMIN),

    // ---- pkg_inventario ----
    MEDICAMENTO_CREAR("pkg_inventario.crear_medicamento", 6, true, ADMIN),
    MEDICAMENTO_ACTUALIZAR("pkg_inventario.actualizar_medicamento", 7, false, ADMIN),
    MEDICAMENTO_ELIMINAR("pkg_inventario.eliminar_medicamento", 1, false, ADMIN),
    REGISTRAR_LOTE("pkg_inventario.registrar_lote", 7, true, ADMIN, ADMIN_SUCURSAL, REGENTE),
    LOTE_ACTUALIZAR("pkg_inventario.actualizar_lote", 4, false, ADMIN, ADMIN_SUCURSAL, REGENTE),
    LOTE_ELIMINAR("pkg_inventario.eliminar_lote", 1, false, ADMIN),

    // ---- pkg_mantenimiento ----
    PROVEEDOR_CREAR("pkg_mantenimiento.crear_proveedor", 3, true, ADMIN, ADMIN_SUCURSAL),
    PROVEEDOR_ACTUALIZAR("pkg_mantenimiento.actualizar_proveedor", 4, false, ADMIN, ADMIN_SUCURSAL),
    PROVEEDOR_ELIMINAR("pkg_mantenimiento.eliminar_proveedor", 1, false, ADMIN),
    CLIENTE_ACTUALIZAR("pkg_mantenimiento.actualizar_cliente", 6, false, ADMIN, ADMIN_SUCURSAL),
    CLIENTE_ELIMINAR("pkg_mantenimiento.eliminar_cliente", 1, false, ADMIN),
    EMPLEADO_ACTUALIZAR("pkg_mantenimiento.actualizar_empleado", 8, false, ADMIN, ADMIN_SUCURSAL),
    EMPLEADO_ELIMINAR("pkg_mantenimiento.eliminar_empleado", 1, false, ADMIN),

    // ---- pkg_sucursales (08) ----
    CIUDAD_OBTENER_O_CREAR("pkg_sucursales.obtener_o_crear_ciudad", 1, true, ADMIN),
    SUCURSAL_CREAR("pkg_sucursales.crear_sucursal", 3, true, ADMIN),
    SUCURSAL_ACTUALIZAR("pkg_sucursales.actualizar_sucursal", 4, false, ADMIN),
    SUCURSAL_ELIMINAR("pkg_sucursales.eliminar_sucursal", 1, false, ADMIN),

    // ---- pkg_traslados (08): transacción explícita con SAVEPOINT / COMMIT / ROLLBACK ----
    LOTE_TRASLADAR("pkg_traslados.trasladar_stock", 4, true, ADMIN, ADMIN_SUCURSAL, REGENTE);

    private final String llamada;
    private final int entradas;
    private final boolean conSalida;
    private final Rol[] roles;

    Operacion(String llamada, int entradas, boolean conSalida, Rol... roles) {
        this.llamada = llamada;
        this.entradas = entradas;
        this.conSalida = conSalida;
        this.roles = roles;
    }

    public String llamada() { return llamada; }
    public int entradas() { return entradas; }
    public boolean conSalida() { return conSalida; }
    public Rol[] roles() { return roles; }
}
