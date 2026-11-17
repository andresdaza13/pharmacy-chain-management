package com.farmacia.model;

/** MODELO de lectura: lote con los datos de medicamento, sucursal y proveedor. */
public record LoteVista(int idLote, String medicamento, String sucursal, String proveedor,
                        int cantidadActual, int cantidadInicial,
                        String fabricacion, String vencimiento, String estado) {

    /** Clase CSS según el estado (VENCIDO, POR_VENCER, VIGENTE). */
    public String clase() {
        return switch (String.valueOf(estado)) {
            case "VENCIDO" -> "vencido";
            case "PROXIMO_A_VENCER", "POR_VENCER" -> "por-vencer";
            default -> "vigente";
        };
    }

    public String etiqueta() {
        return switch (String.valueOf(estado)) {
            case "VENCIDO" -> "Vencido";
            case "PROXIMO_A_VENCER", "POR_VENCER" -> "Próximo a vencer";
            default -> "Vigente";
        };
    }
}
