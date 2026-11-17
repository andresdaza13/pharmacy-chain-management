package com.farmacia.model;

/** PACIENTE (cliente de la farmacia), leído de la vista vw_pacientes = Persona + Cliente + teléfono. */
public record Cliente(int id, String nombre, String apellido, String documento,
                      String email, String direccion, String fechaRegistro, String telefono) {}
