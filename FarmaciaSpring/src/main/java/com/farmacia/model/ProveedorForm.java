package com.farmacia.model;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/** DTO del formulario de proveedor. */
@Data
public class ProveedorForm {
    private Integer id;
    @NotBlank(message = "El NIT es obligatorio")
    private String nit;
    @NotBlank(message = "El nombre es obligatorio")
    private String nombre;
    private String direccion;

    public static ProveedorForm desde(Proveedor p) {
        ProveedorForm f = new ProveedorForm();
        f.setId(p.id()); f.setNit(p.nit()); f.setNombre(p.nombre());
        f.setDireccion(p.direccion());
        return f;
    }
}
