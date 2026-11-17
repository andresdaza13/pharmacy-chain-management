package com.farmacia.service;

import lombok.RequiredArgsConstructor;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.Categoria;
import com.farmacia.model.Medicamento;
import com.farmacia.model.MedicamentoForm;
import com.farmacia.repository.MedicamentoRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/** SERVICIO: lógica de negocio. El controlador nunca habla directo con la base de datos. */
@RequiredArgsConstructor
@Service
public class MedicamentoService {

    private final MedicamentoRepository repositorio;


    public List<Medicamento> listar(String filtro) {
        return repositorio.buscarPorNombre(filtro == null ? "" : filtro);
    }

    public Medicamento obtener(int id) {
        return repositorio.buscarPorId(id)
                .orElseThrow(() -> new ReglaNegocioException("No existe el medicamento con ID " + id));
    }

    public List<Categoria> categorias() {
        return repositorio.listarCategorias();
    }

    /** Crea si el formulario no trae ID; si lo trae, actualiza. */
    @Transactional
    public void guardar(MedicamentoForm f) {
        String nombre = f.getNombre().trim();
        if (f.getId() == null) {
            repositorio.crear(nombre, f.getNombreGenerico().trim(), f.getPresentacion().trim(),
                    f.getIdCategoria(), f.getPrecio(), f.isRequiereReceta());
        } else {
            repositorio.actualizar(f.getId(), nombre, f.getNombreGenerico().trim(), f.getPresentacion().trim(),
                    f.getIdCategoria(), f.getPrecio(), f.isRequiereReceta());
        }
    }

    @Transactional
    public void eliminar(int id) {
        try {
            repositorio.eliminar(id);
        } catch (DataIntegrityViolationException ex) { // ORA-02292: tiene lotes asociados
            throw new ReglaNegocioException("No se puede eliminar: el medicamento tiene lotes asociados.");
        }
    }
}
