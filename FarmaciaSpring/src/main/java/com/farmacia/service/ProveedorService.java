package com.farmacia.service;

import lombok.RequiredArgsConstructor;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.Proveedor;
import com.farmacia.model.ProveedorForm;
import com.farmacia.repository.ProveedorRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
@Service
public class ProveedorService {

    private final ProveedorRepository repositorio;


    public List<Proveedor> listar(String filtro) {
        return repositorio.buscar(filtro == null ? "" : filtro);
    }

    public Proveedor obtener(int id) {
        return repositorio.buscarPorId(id)
                .orElseThrow(() -> new ReglaNegocioException("No existe el proveedor con ID " + id));
    }

    @Transactional
    public void guardar(ProveedorForm f) {
        String nit = f.getNit().trim(), nombre = f.getNombre().trim();
        if (f.getId() == null) {
            repositorio.crear(nit, nombre, f.getDireccion());
        } else {
            repositorio.actualizar(f.getId(), nit, nombre, f.getDireccion());
        }
    }

    @Transactional
    public void eliminar(int id) {
        repositorio.eliminar(id);
    }
}
