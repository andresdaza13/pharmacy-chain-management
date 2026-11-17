package com.farmacia.repository;

import lombok.RequiredArgsConstructor;
import com.farmacia.despacho.DespachadorProcedimientos;
import com.farmacia.despacho.Operacion;
import com.farmacia.model.LoteForm;
import com.farmacia.model.LoteVista;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Date;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/** Lectura de lotes con SELECT y escritura con pkg_inventario. */
@RequiredArgsConstructor
@Repository
public class LoteRepository {

    private static final String SQL = """
            SELECT l.id_lote, m.nombre_comercial, s.nombre AS sucursal, p.nombre AS proveedor,
                   l.cantidad_actual, l.cantidad_inicial,
                   TO_CHAR(l.fecha_fabricacion, 'DD/MM/YYYY') AS fabricacion,
                   TO_CHAR(l.fecha_vencimiento, 'DD/MM/YYYY') AS vencimiento,
                   fn_estado_lote(l.id_lote) AS estado   -- dominio dinámico: lo calcula Oracle
              FROM Lote l
              JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
              JOIN Sucursal s    ON s.id_sucursal    = l.id_sucursal
              JOIN Proveedor p   ON p.id_proveedor   = l.id_proveedor
             ORDER BY l.fecha_vencimiento
            """;

    private final JdbcTemplate jdbc;
    private final DespachadorProcedimientos despachador;


    public List<LoteVista> listar() {
        return jdbc.query(SQL, (rs, fila) -> new LoteVista(
                rs.getInt("id_lote"),
                rs.getString("nombre_comercial"),
                rs.getString("sucursal"),
                rs.getString("proveedor"),
                rs.getInt("cantidad_actual"),
                rs.getInt("cantidad_inicial"),
                rs.getString("fabricacion"),
                rs.getString("vencimiento"),
                rs.getString("estado")));
    }

    public Optional<LoteForm> buscarFormPorId(int id) {
        return jdbc.query("""
                SELECT id_lote, id_medicamento, id_sucursal, id_proveedor, id_empleado,
                       fecha_fabricacion, fecha_vencimiento, cantidad_actual
                  FROM Lote WHERE id_lote = ?""", (rs, fila) -> {
            LoteForm f = new LoteForm();
            f.setId(rs.getInt("id_lote"));
            f.setIdMedicamento(rs.getInt("id_medicamento"));
            f.setIdSucursal(rs.getInt("id_sucursal"));
            f.setIdProveedor(rs.getInt("id_proveedor"));
            f.setIdEmpleado(rs.getInt("id_empleado"));
            f.setFechaFabricacion(aLocalDate(rs.getDate("fecha_fabricacion")));
            f.setFechaVencimiento(aLocalDate(rs.getDate("fecha_vencimiento")));
            f.setCantidad(rs.getInt("cantidad_actual"));
            return f;
        }, id).stream().findFirst();
    }

    public int crear(int idMedicamento, int idSucursal, int idProveedor, int idEmpleado,
                     LocalDate fabricacion, LocalDate vencimiento, int cantidad) {
        return despachador.ejecutar(Operacion.REGISTRAR_LOTE,
                idMedicamento, idSucursal, idProveedor, idEmpleado, fabricacion, vencimiento, cantidad);
    }

    public void actualizar(int id, LocalDate fabricacion, LocalDate vencimiento, int cantidadActual) {
        despachador.ejecutar(Operacion.LOTE_ACTUALIZAR, id, fabricacion, vencimiento, cantidadActual);
    }

    public void eliminar(int id) {
        despachador.ejecutar(Operacion.LOTE_ELIMINAR, id);
    }

    /** pkg_traslados.trasladar_stock: transacción explícita (SAVEPOINT / COMMIT / ROLLBACK) en Oracle. */
    public int trasladar(int idLote, int idSucursalDestino, int cantidad, int idEmpleado) {
        return despachador.ejecutar(Operacion.LOTE_TRASLADAR, idLote, idSucursalDestino, cantidad, idEmpleado);
    }

    private static LocalDate aLocalDate(Date d) {
        return d == null ? null : d.toLocalDate();
    }
}
