package com.farmacia.repository;

import com.farmacia.model.Reportes.*;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Date;
import java.time.LocalDate;
import java.util.List;

/**
 * Lee las VISTAS de reportes (vw_rep_*) creadas en 06_logica_negocio.sql.
 * La lógica pesada (joins, RANK, funciones fn_*) vive en Oracle; Java solo filtra y agrupa.
 */
@Repository
@RequiredArgsConstructor
public class ReporteRepository {

    private final JdbcTemplate jdbc;

    /** agrupacion: "sucursal" | "empleado" | "dia". Se elige de una lista cerrada (nunca texto libre en el SQL). */
    public List<VentasAgrupadas> ventas(String agrupacion, LocalDate desde, LocalDate hasta) {
        String col = switch (agrupacion) {
            case "empleado" -> "empleado || ' — ' || sucursal";
            case "dia" -> "TO_CHAR(dia, 'YYYY-MM-DD')";
            default -> "sucursal";
        };
        return jdbc.query("""
                SELECT %s AS grupo, COUNT(*) AS cantidad, SUM(total) AS total
                  FROM vw_rep_ventas
                 WHERE dia BETWEEN ? AND ?
                 GROUP BY %s
                 ORDER BY %s""".formatted(col, col, agrupacion.equals("dia") ? "1" : "3 DESC"),
                (rs, i) -> new VentasAgrupadas(rs.getString(1), rs.getInt(2), rs.getBigDecimal(3)),
                Date.valueOf(desde), Date.valueOf(hasta));
    }

    public List<MasVendido> masVendidos(int top) {
        return jdbc.query("""
                SELECT sucursal, puesto, medicamento, unidades, ingresos
                  FROM vw_rep_mas_vendidos WHERE puesto <= ?
                 ORDER BY sucursal, puesto, medicamento""",
                (rs, i) -> new MasVendido(rs.getString(1), rs.getInt(2), rs.getString(3), rs.getInt(4),
                        rs.getBigDecimal(5)), top);
    }

    public List<LoteAlerta> lotesAlerta() {
        return jdbc.query("""
                SELECT sucursal, id_lote, medicamento, cantidad_actual, fecha_vencimiento, dias, estado
                  FROM vw_rep_lotes_alerta ORDER BY sucursal, dias""",
                (rs, i) -> new LoteAlerta(rs.getString(1), rs.getInt(2), rs.getString(3), rs.getInt(4),
                        rs.getDate(5).toLocalDate(), rs.getInt(6), rs.getString(7)));
    }

    public List<VentaReceta> ventasReceta() {
        return jdbc.query("""
                SELECT id_venta, TO_CHAR(fecha_venta, 'DD/MM/YYYY HH24:MI'), sucursal, cliente,
                       nombre_medico, registro_medico, medicamentos, total
                  FROM vw_rep_ventas_receta ORDER BY fecha_venta DESC""",
                (rs, i) -> new VentaReceta(rs.getInt(1), rs.getString(2), rs.getString(3), rs.getString(4),
                        rs.getString(5), rs.getString(6), rs.getString(7), rs.getBigDecimal(8)));
    }

    public List<LoteProveedor> lotesPorProveedor() {
        return jdbc.query("""
                SELECT id_lote, proveedor, nit, empleado, cargo, medicamento, sucursal,
                       fecha_vencimiento, cantidad_inicial, cantidad_actual
                  FROM vw_rep_lotes_proveedor ORDER BY proveedor, id_lote""",
                (rs, i) -> new LoteProveedor(rs.getInt(1), rs.getString(2), rs.getString(3), rs.getString(4),
                        rs.getString(5), rs.getString(6), rs.getString(7), rs.getDate(8).toLocalDate(),
                        rs.getInt(9), rs.getInt(10)));
    }

    // ===================== ESTADÍSTICAS (gráficas) =====================
    private static final org.springframework.jdbc.core.RowMapper<Serie> SERIE =
            (rs, i) -> new Serie(rs.getString(1), rs.getBigDecimal(2), rs.getBigDecimal(3));

    /** KPI del periodo. El total sale de la FUNCIÓN PARAMETRIZADA pkg_reportes.fn_total_vendido. */
    public Indicadores indicadores(LocalDate desde, LocalDate hasta) {
        Date d = Date.valueOf(desde), h = Date.valueOf(hasta);
        return jdbc.queryForObject("""
                SELECT pkg_reportes.fn_total_vendido(?, ?),
                       (SELECT COUNT(*) FROM vw_rep_ventas WHERE dia BETWEEN ? AND ?),
                       (SELECT NVL(SUM(vl.cantidad), 0)
                          FROM Venta_Lote vl JOIN Venta v ON v.id_venta = vl.id_venta
                         WHERE v.estado = 'ACTIVA' AND TRUNC(v.fecha_venta) BETWEEN ? AND ?),
                       (SELECT COUNT(DISTINCT id_cliente) FROM Venta
                         WHERE estado = 'ACTIVA' AND TRUNC(fecha_venta) BETWEEN ? AND ?)
                  FROM dual""",
                (rs, i) -> new Indicadores(rs.getBigDecimal(1), rs.getInt(2), rs.getInt(3), rs.getInt(4)),
                d, h, d, h, d, h, d, h);
    }

    /** Ventas por día (línea). */
    public List<Serie> ventasPorDia(LocalDate desde, LocalDate hasta) {
        return jdbc.query("""
                SELECT TO_CHAR(dia, 'DD/MM'), SUM(total), COUNT(*)
                  FROM vw_rep_ventas WHERE dia BETWEEN ? AND ?
                 GROUP BY dia ORDER BY dia""", SERIE, Date.valueOf(desde), Date.valueOf(hasta));
    }

    /** Por sucursal: usa la COLECCIÓN de pkg_reportes a través de la función PIPELINED. */
    public List<Serie> ventasPorSucursal(LocalDate desde, LocalDate hasta) {
        return jdbc.query("""
                SELECT sucursal, total_vendido, ticket_promedio
                  FROM TABLE(pkg_reportes.fn_resumen_sucursales(?, ?))""",
                SERIE, Date.valueOf(desde), Date.valueOf(hasta));
    }

    /** Método de pago (dona). */
    public List<Serie> ventasPorMetodo(LocalDate desde, LocalDate hasta) {
        return jdbc.query("""
                SELECT INITCAP(metodo_pago), SUM(total), COUNT(*)
                  FROM vw_rep_ventas WHERE dia BETWEEN ? AND ?
                 GROUP BY metodo_pago ORDER BY 2 DESC""", SERIE, Date.valueOf(desde), Date.valueOf(hasta));
    }

    /** Top medicamentos por unidades (barras horizontales). */
    public List<Serie> topMedicamentos(LocalDate desde, LocalDate hasta) {
        return jdbc.query("""
                SELECT m.nombre_comercial, SUM(vl.cantidad), SUM(vl.cantidad * vl.precio_unitario)
                  FROM Venta_Lote vl
                  JOIN Venta v       ON v.id_venta = vl.id_venta AND v.estado = 'ACTIVA'
                  JOIN Lote l        ON l.id_lote = vl.id_lote
                  JOIN Medicamento m ON m.id_medicamento = l.id_medicamento
                 WHERE TRUNC(v.fecha_venta) BETWEEN ? AND ?
                 GROUP BY m.nombre_comercial
                 ORDER BY 2 DESC FETCH FIRST 7 ROWS ONLY""", SERIE, Date.valueOf(desde), Date.valueOf(hasta));
    }

    /** Inventario por estado del lote (usa la función fn_estado_lote). */
    public List<Serie> lotesPorEstado() {
        return jdbc.query("""
                SELECT estado, COUNT(*), SUM(cantidad_actual)
                  FROM (SELECT fn_estado_lote(id_lote) AS estado, cantidad_actual FROM Lote WHERE cantidad_actual > 0)
                 GROUP BY estado
                 ORDER BY DECODE(estado, 'VIGENTE', 1, 'PROXIMO_A_VENCER', 2, 3)""", SERIE);
    }

    /** Números del panel de inicio. Cada consulta es pequeña; las funciones fn_* hacen el cálculo. */
    public Resumen resumen() {
        return jdbc.queryForObject("""
                SELECT pkg_reportes.fn_total_vendido(TRUNC(SYSDATE), TRUNC(SYSDATE)),   -- función del paquete
                       pkg_reportes.fn_ventas_hoy,                                     -- función simple
                       (SELECT COUNT(*) FROM vw_rep_lotes_alerta WHERE estado = 'PROXIMO_A_VENCER'),
                       (SELECT COUNT(*) FROM vw_rep_lotes_alerta WHERE estado = 'VENCIDO'),
                       (SELECT COUNT(*) FROM Medicamento),
                       (SELECT COUNT(*) FROM Cliente)
                  FROM dual""",
                (rs, i) -> new Resumen(rs.getBigDecimal(1), rs.getInt(2), rs.getInt(3), rs.getInt(4),
                        rs.getInt(5), rs.getInt(6)));
    }
}
