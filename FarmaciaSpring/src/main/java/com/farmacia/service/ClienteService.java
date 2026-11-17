package com.farmacia.service;

import lombok.RequiredArgsConstructor;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.Cliente;
import com.farmacia.model.ClienteForm;
import com.farmacia.repository.ClienteRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
@Service
public class ClienteService {

    private final ClienteRepository repositorio;


    public List<Cliente> listar(String filtro) {
        return repositorio.buscar(filtro == null ? "" : filtro);
    }

    public Cliente obtener(int id) {
        return repositorio.buscarPorId(id)
                .orElseThrow(() -> new ReglaNegocioException("No existe el paciente con ID " + id));
    }

    /** Importante: crear/actualizar tocan DOS tablas (Persona y Cliente), por eso va en una transacción. */
    @Transactional
    public void guardar(ClienteForm f) {
        if (f.getId() == null) {
            repositorio.crear(f.getNombre().trim(), f.getApellido().trim(), f.getDocumento().trim(),
                    vacio(f.getEmail()), vacio(f.getDireccion()), vacio(f.getTelefono()));
        } else {
            repositorio.actualizar(f.getId(), f.getNombre().trim(), f.getApellido().trim(),
                    f.getDocumento().trim(), vacio(f.getEmail()), vacio(f.getDireccion()), vacio(f.getTelefono()));
        }
    }

    private static String vacio(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    @Transactional
    public void eliminar(int id) {
        repositorio.eliminar(id);
    }
}
