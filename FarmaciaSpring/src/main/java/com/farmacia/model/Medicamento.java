package com.farmacia.model;

import java.math.BigDecimal;

/** MODELO: medicamento tal como se lee de la base de datos. */
public record Medicamento(int id, String nombre, String nombreGenerico, String presentacion,
                          int idCategoria, String categoria, BigDecimal precio, boolean requiereReceta) {}
