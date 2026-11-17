package com.farmacia.model;

import lombok.Data;
import lombok.EqualsAndHashCode;

/** DTO del formulario de cliente. callSuper = true: equals/hashCode incluyen los campos de PersonaForm. */
@Data
@EqualsAndHashCode(callSuper = true)
public class ClienteForm extends PersonaForm {
    private String direccion;
    private String telefono;

    public static ClienteForm desde(Cliente c) {
        ClienteForm f = new ClienteForm();
        f.setId(c.id()); f.setNombre(c.nombre()); f.setApellido(c.apellido());
        f.setDocumento(c.documento()); f.setEmail(c.email()); f.setDireccion(c.direccion());
        f.setTelefono(c.telefono());
        return f;
    }
}
