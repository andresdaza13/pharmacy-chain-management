package com.farmacia.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/** DTO del formulario de sucursal. Se elige una ciudad existente O se escribe una nueva. */
@Data
public class SucursalForm {
    private Integer id;
    @NotBlank(message = "El nombre es obligatorio")
    @Size(max = 100, message = "Máximo 100 caracteres")
    private String nombre;
    @Size(max = 150, message = "Máximo 150 caracteres")
    private String direccion;
    private Integer idCiudad;
    @Size(max = 80, message = "Máximo 80 caracteres")
    private String nuevaCiudad;

    public static SucursalForm desde(Sucursal s) {
        SucursalForm f = new SucursalForm();
        f.setId(s.id()); f.setNombre(s.nombre()); f.setDireccion(s.direccion()); f.setIdCiudad(s.idCiudad());
        return f;
    }
}
