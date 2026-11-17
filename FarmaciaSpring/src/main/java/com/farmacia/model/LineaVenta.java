package com.farmacia.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Una línea del formulario de venta: qué medicamento y cuántas unidades. */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class LineaVenta {
    private Integer idMedicamento;
    private Integer cantidad;
}
