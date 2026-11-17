package com.farmacia.model;

import java.math.BigDecimal;

/** Una línea de una venta ya registrada: de qué lote salieron las unidades. */
public record LineaDetalle(String medicamento, int idLote, int cantidad, BigDecimal precio, BigDecimal subtotal) {}
