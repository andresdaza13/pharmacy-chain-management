package com.farmacia.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

@Data
@EqualsAndHashCode(callSuper = true)
public class EmpleadoForm extends PersonaForm {
    @NotBlank(message = "El cargo es obligatorio")
    private String cargo;
    @NotNull(message = "El salario es obligatorio")
    @PositiveOrZero(message = "El salario no puede ser negativo")
    private BigDecimal salario;
    @NotNull(message = "Selecciona una sucursal")
    private Integer idSucursal;

    public static EmpleadoForm desde(Empleado e) {
        EmpleadoForm f = new EmpleadoForm();
        f.setId(e.id()); f.setNombre(e.nombre()); f.setApellido(e.apellido());
        f.setDocumento(e.documento()); f.setEmail(e.email());
        f.setCargo(e.cargo()); f.setSalario(e.salario()); f.setIdSucursal(e.idSucursal());
        return f;
    }
}
