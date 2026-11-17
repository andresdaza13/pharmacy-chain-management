package com.farmacia.model;

import java.math.BigDecimal;

public record Empleado(int id, String nombre, String apellido, String documento, String email,
                       String cargo, BigDecimal salario, int idSucursal, String sucursal) {}
