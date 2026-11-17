package com.farmacia.model;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * Campos comunes de Cliente y Empleado (ambos "son" una Persona). Herencia en el DTO.
 * LOMBOK: @Data genera getters, setters, equals, hashCode y toString en tiempo de compilación.
 */
@Data
public abstract class PersonaForm {
    private Integer id;
    @NotBlank(message = "El nombre es obligatorio")
    private String nombre;
    @NotBlank(message = "El apellido es obligatorio")
    private String apellido;
    @NotBlank(message = "El documento es obligatorio")
    private String documento;
    @Email(message = "El correo no tiene un formato válido")
    private String email;
}
