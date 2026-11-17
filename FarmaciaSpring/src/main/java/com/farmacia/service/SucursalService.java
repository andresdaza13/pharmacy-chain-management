package com.farmacia.service;

import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.Opcion;
import com.farmacia.model.Sucursal;
import com.farmacia.model.SucursalForm;
import com.farmacia.repository.SucursalRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class SucursalService {

    private final SucursalRepository repositorio;

    public List<Sucursal> listar() { return repositorio.listar(); }

    public List<Opcion> ciudades() { return repositorio.ciudades(); }

    public Sucursal obtener(int id) {
        return repositorio.buscarPorId(id)
                .orElseThrow(() -> new ReglaNegocioException("No existe la sucursal con ID " + id));
    }

    /** Si se escribió una ciudad nueva, se crea primero (misma transacción que la sucursal). */
    @Transactional
    public void guardar(SucursalForm f) {
        Integer idCiudad = f.getIdCiudad();
        if (f.getNuevaCiudad() != null && !f.getNuevaCiudad().isBlank()) {
            idCiudad = repositorio.obtenerOCrearCiudad(f.getNuevaCiudad().trim());
        }
        if (idCiudad == null) throw new ReglaNegocioException("Elige la ciudad o escribe una nueva.");
        String direccion = f.getDireccion() == null || f.getDireccion().isBlank() ? null : f.getDireccion().trim();
        if (f.getId() == null) {
            repositorio.crear(f.getNombre().trim(), direccion, idCiudad);
        } else {
            repositorio.actualizar(f.getId(), f.getNombre().trim(), direccion, idCiudad);
        }
    }

    @Transactional
    public void eliminar(int id) { repositorio.eliminar(id); }
}
