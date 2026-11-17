package com.farmacia.model;

import java.math.BigDecimal;

/** Medicamento disponible para vender, con su stock vigente (lotes no vencidos). */
public record MedicamentoVenta(int id, String nombre, BigDecimal precio, boolean requiereReceta, int stock) {

    public String etiqueta() {
        return nombre + " — $" + precio.stripTrailingZeros().toPlainString()
                + " — stock " + stock + (requiereReceta ? " — requiere receta" : "");
    }
}
