package com.farmacia.service;

import lombok.RequiredArgsConstructor;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.Empleado;
import com.farmacia.model.EmpleadoForm;
import com.farmacia.repository.EmpleadoRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
@Service
public class EmpleadoService {

    private final EmpleadoRepository repositorio;


    public List<Empleado> listar(String filtro) {
        return repositorio.buscar(filtro == null ? "" : filtro);
    }

    public Empleado obtener(int id) {
        return repositorio.buscarPorId(id)
                .orElseThrow(() -> new ReglaNegocioException("No existe el empleado con ID " + id));
    }

    @Transactional
    public void guardar(EmpleadoForm f) {
        if (f.getId() == null) {
            repositorio.crear(f.getNombre().trim(), f.getApellido().trim(), f.getDocumento().trim(),
                    f.getEmail(), f.getCargo().trim(), f.getSalario(), f.getIdSucursal());
        } else {
            repositorio.actualizar(f.getId(), f.getNombre().trim(), f.getApellido().trim(),
                    f.getDocumento().trim(), f.getEmail(), f.getCargo().trim(), f.getSalario(), f.getIdSucursal());
        }
    }

    @Transactional
    public void eliminar(int id) {
        repositorio.eliminar(id);
    }
}
