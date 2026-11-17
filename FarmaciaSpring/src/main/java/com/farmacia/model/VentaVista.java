package com.farmacia.model;

import java.math.BigDecimal;

/**
 * Venta con los nombres de cliente, empleado y sucursal ya resueltos.
 * Es un RECORD (Java 16+): inmutable, con constructor, getters (id(), total()...), equals y toString
 * generados por el propio lenguaje. Por eso aquí NO hace falta Lombok.
 * estado: ACTIVA | ANULADA (una venta nunca se borra: se anula y queda como historial).
 */
public record VentaVista(int id, String codigoFactura, String fecha, String metodoPago, BigDecimal total, String estado,
                         String empleado, String cliente, String sucursal,
                         String nombreMedico, String registroMedico) {
    public boolean conReceta() { return registroMedico != null; }
    public boolean anulada() { return "ANULADA".equals(estado); }
}
