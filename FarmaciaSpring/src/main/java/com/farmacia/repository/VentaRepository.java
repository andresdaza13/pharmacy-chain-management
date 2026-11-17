package com.farmacia.repository;

import com.farmacia.despacho.DespachadorProcedimientos;
import com.farmacia.despacho.Operacion;
import com.farmacia.model.VentaVista;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/** Lectura con SELECT; escritura con pkg_ventas (paquete del equipo). */
@Repository
@RequiredArgsConstructor
public class VentaRepository {

    private static final String SELECT_BASE = """
            SELECT v.id_venta, v.codigo_factura, TO_CHAR(v.fecha_venta, 'DD/MM/YYYY HH24:MI') AS fecha,
                   v.metodo_pago, v.total, v.estado,
                   pe.nombre || ' ' || pe.apellido AS empleado,
                   pc.nombre || ' ' || pc.apellido AS cliente,
                   s.nombre AS sucursal,
                   v.nombre_medico, v.registro_medico
              FROM Venta v
              JOIN Persona pe ON pe.id_persona = v.id_empleado
              JOIN Persona pc ON pc.id_persona = v.id_cliente
              JOIN Sucursal s ON s.id_sucursal = v.id_sucursal
            """;

    private static final RowMapper<VentaVista> MAPPER = (rs, fila) -> new VentaVista(
            rs.getInt("id_venta"), rs.getString("codigo_factura"), rs.getString("fecha"), rs.getString("metodo_pago"),
            rs.getBigDecimal("total"), rs.getString("estado"), rs.getString("empleado"),
            rs.getString("cliente"), rs.getString("sucursal"),
            rs.getString("nombre_medico"), rs.getString("registro_medico"));

    private final JdbcTemplate jdbc;
    private final DespachadorProcedimientos despachador;

    /** Ventas de un día; si fecha es null, todas. Si idSucursal no es null, solo esa sucursal. */
    public List<VentaVista> listar(LocalDate fecha, Integer idSucursal) {
        StringBuilder sql = new StringBuilder(SELECT_BASE).append(" WHERE 1 = 1");
        List<Object> params = new ArrayList<>();
        if (fecha != null) { sql.append(" AND TRUNC(v.fecha_venta) = ?"); params.add(java.sql.Date.valueOf(fecha)); }
        if (idSucursal != null) { sql.append(" AND v.id_sucursal = ?"); params.add(idSucursal); }
        sql.append(" ORDER BY v.fecha_venta DESC, v.id_venta DESC");
        return jdbc.query(sql.toString(), MAPPER, params.toArray());
    }

    public Optional<VentaVista> buscarPorId(int id) {
        return jdbc.query(SELECT_BASE + " WHERE v.id_venta = ?", MAPPER, id).stream().findFirst();
    }

    /** La venta se realiza en la sucursal del empleado (MER: Sucursal realiza Venta). */
    public Optional<Integer> sucursalDeEmpleado(int idEmpleado) {
        return jdbc.queryForList("SELECT id_sucursal FROM Empleado WHERE id_empleado = ?", Integer.class, idEmpleado)
                .stream().findFirst();
    }

    /** Paso 1: cabecera. trg_venta_bi valida cargo y sucursal, y deja total = 0 y estado = ACTIVA. */
    public int crearCabecera(int idCliente, int idEmpleado, int idSucursal, String metodoPago,
                             String nombreMedico, String registroMedico) {
        return despachador.ejecutar(Operacion.VENTA_REGISTRAR,
                idCliente, idEmpleado, idSucursal, metodoPago, nombreMedico, registroMedico);
    }

    /**
     * Paso 2 (una vez por medicamento): agregar_medicamento reparte la cantidad entre lotes (FEFO);
     * trg_venta_lote_bi valida y trg_venta_lote_ai descuenta el stock y suma el total.
     */
    public void agregarMedicamento(int idVenta, int idMedicamento, int cantidad) {
        despachador.ejecutar(Operacion.VENTA_AGREGAR_MEDICAMENTO, idVenta, idMedicamento, cantidad);
    }

    /** Anular: devuelve el stock y marca ANULADA. El detalle NO se borra (trg_venta_lote_inmutable). */
    public void anular(int id) {
        despachador.ejecutar(Operacion.VENTA_ANULAR, id);
    }
}
