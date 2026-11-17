package com.farmacia.repository;

import com.farmacia.model.LineaDetalle;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * Detalle de la venta (relación N:M "Incluye" entre Venta y Lote = tabla Venta_Lote).
 * Java NO toca el stock: lo hacen pkg_ventas.agregar_medicamento y el trigger trg_venta_lote_ai.
 * Aquí solo se lee.
 */
@Repository
@RequiredArgsConstructor
public class VentaDetalleRepository {

    private final JdbcTemplate jdbc;

    public List<LineaDetalle> detalle(int idVenta) {
        return jdbc.query("""
                SELECT m.nombre_comercial, vl.id_lote, vl.cantidad, vl.precio_unitario,
                       vl.cantidad * vl.precio_unitario AS subtotal
                  FROM Venta_Lote vl
                  JOIN Lote l        ON l.id_lote = vl.id_lote
                  JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
                 WHERE vl.id_venta = ?
                 ORDER BY m.nombre_comercial, vl.id_lote""",
                (rs, fila) -> new LineaDetalle(rs.getString(1), rs.getInt(2), rs.getInt(3),
                        rs.getBigDecimal(4), rs.getBigDecimal(5)), idVenta);
    }
}
