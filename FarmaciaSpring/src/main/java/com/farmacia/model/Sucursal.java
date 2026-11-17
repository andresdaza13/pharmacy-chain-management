package com.farmacia.model;

/** Sucursal con su ciudad y cuántos empleados y lotes tiene (para saber si se puede eliminar). */
public record Sucursal(int id, String nombre, String direccion, int idCiudad, String ciudad,
                       int empleados, int lotes, int ventas) {
    public boolean eliminable() { return empleados == 0 && lotes == 0 && ventas == 0; }
}
