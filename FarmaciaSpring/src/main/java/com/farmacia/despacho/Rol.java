package com.farmacia.despacho;

/**
 * Niveles de acceso de la aplicación (Spring los usa como ROLE_ADMIN, ROLE_VENDEDOR, ...).
 * Cada uno corresponde a un ROL DE ORACLE de 04_roles.sql (ver AutenticacionFarmacia):
 *
 *  ADMIN          (DBA / admin_farmacia)   todo.
 *  GERENCIA       (gerencia)               reportes y consulta de todo; sin escritura.
 *  ADMIN_SUCURSAL (administrador_sucursal) empleados, clientes, lotes y proveedores.
 *  REGENTE        (regente)                ventas (y autoriza las que llevan receta) + lotes.
 *  VENDEDOR       (vendedor)               ventas sin receta, consulta medicamentos y lotes.
 *  AUDITOR        (auditor)                solo lectura: listados y reportes.
 */
public enum Rol {
    ADMIN("Administrador"),
    GERENCIA("Gerencia"),
    ADMIN_SUCURSAL("Administrador de sucursal"),
    REGENTE("Regente farmacéutico"),
    VENDEDOR("Vendedor"),
    AUDITOR("Auditor");

    private final String etiqueta;

    Rol(String etiqueta) { this.etiqueta = etiqueta; }

    public String etiqueta() { return etiqueta; }
    public String autoridad() { return "ROLE_" + name(); }
}
