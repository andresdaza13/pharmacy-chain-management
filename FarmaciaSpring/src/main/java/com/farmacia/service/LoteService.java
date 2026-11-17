package com.farmacia.service;

import lombok.RequiredArgsConstructor;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.LoteForm;
import com.farmacia.model.LoteVista;
import com.farmacia.repository.LoteRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
@Service
public class LoteService {

    private final LoteRepository repositorio;


    public List<LoteVista> listar() {
        return repositorio.listar();
    }

    /** Lote con nombres (medicamento, sucursal...) para mostrarlo en pantalla. */
    public com.farmacia.model.LoteVista vista(int id) {
        return repositorio.listar().stream().filter(l -> l.idLote() == id).findFirst()
                .orElseThrow(() -> new ReglaNegocioException("No existe el lote con ID " + id));
    }

    public LoteForm obtener(int id) {
        return repositorio.buscarFormPorId(id)
                .orElseThrow(() -> new ReglaNegocioException("No existe el lote con ID " + id));
    }

    @Transactional
    public void guardar(LoteForm f) {
        // Reglas de negocio: se validan aquí y no en el controlador ni en el HTML.
        if (!f.getFechaVencimiento().isAfter(f.getFechaFabricacion())) {
            throw new ReglaNegocioException("La fecha de vencimiento debe ser posterior a la de fabricación.");
        }
        if (f.getId() == null) {
            if (f.getIdMedicamento() == null || f.getIdSucursal() == null
                    || f.getIdProveedor() == null || f.getIdEmpleado() == null) {
                throw new ReglaNegocioException("Selecciona medicamento, sucursal, proveedor y empleado.");
            }
            if (f.getCantidad() <= 0) {
                throw new ReglaNegocioException("La cantidad inicial debe ser mayor que cero.");
            }
            repositorio.crear(f.getIdMedicamento(), f.getIdSucursal(), f.getIdProveedor(), f.getIdEmpleado(),
                    f.getFechaFabricacion(), f.getFechaVencimiento(), f.getCantidad());
        } else {
            repositorio.actualizar(f.getId(), f.getFechaFabricacion(), f.getFechaVencimiento(), f.getCantidad());
        }
    }

    /**
     * SIN @Transactional a propósito: la transacción la controla Oracle dentro de
     * pkg_traslados.trasladar_stock (SAVEPOINT al inicio, COMMIT si todo sale bien,
     * ROLLBACK TO SAVEPOINT si algo falla). Así se demuestra una transacción explícita en PL/SQL.
     */
    public int trasladar(int idLote, Integer idSucursalDestino, Integer cantidad, Integer idEmpleado) {
        if (idSucursalDestino == null || cantidad == null || idEmpleado == null) {
            throw new ReglaNegocioException("Elige la sucursal de destino, la cantidad y quién recibe.");
        }
        return repositorio.trasladar(idLote, idSucursalDestino, cantidad, idEmpleado);
    }

    @Transactional
    public void eliminar(int id) {
        repositorio.eliminar(id);
    }
}
