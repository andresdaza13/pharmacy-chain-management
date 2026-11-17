package com.farmacia.model;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Filas de los cinco reportes del documento. Un record por reporte (cada vista vw_rep_*). */
public final class Reportes {
    private Reportes() {}

    /** R1: total vendido agrupado (por sucursal, por empleado o por día). */
    public record VentasAgrupadas(String grupo, int cantidad, BigDecimal total) {
        /** Ancho de la barra (0-100) relativo al mayor total del reporte. */
        public int porcentaje(BigDecimal maximo) {
            if (total == null || maximo == null || maximo.signum() == 0) return 0;
            return total.multiply(BigDecimal.valueOf(100)).divide(maximo, 0, java.math.RoundingMode.HALF_UP).intValue();
        }
    }

    /** R2: medicamentos más vendidos por sucursal. */
    public record MasVendido(String sucursal, int puesto, String medicamento, int unidades, BigDecimal ingresos) {}

    /** R3: lotes vencidos o próximos a vencer. */
    public record LoteAlerta(String sucursal, int idLote, String medicamento, int cantidad,
                             LocalDate vencimiento, int dias, String estado) {
        public boolean vencido() { return "VENCIDO".equals(estado); }
    }

    /** R4: ventas con receta. */
    public record VentaReceta(int idVenta, String fecha, String sucursal, String cliente, String medico,
                              String registro, String medicamentos, BigDecimal total) {}

    /** R5: lotes por proveedor y empleado responsable. */
    public record LoteProveedor(int idLote, String proveedor, String nit, String empleado, String cargo,
                                String medicamento, String sucursal, LocalDate vencimiento, int inicial, int actual) {}

    /** Un punto de una gráfica: etiqueta + valor principal + valor secundario (opcional). */
    public record Serie(String etiqueta, BigDecimal valor, BigDecimal valor2) {}

    /** Indicadores (KPI) del periodo para la pantalla de estadísticas. */
    public record Indicadores(BigDecimal totalVendido, int numVentas, int unidades, int pacientesAtendidos) {
        public BigDecimal ticketPromedio() {
            return numVentas == 0 ? BigDecimal.ZERO
                    : totalVendido.divide(BigDecimal.valueOf(numVentas), 0, java.math.RoundingMode.HALF_UP);
        }
    }

    /** Tarjetas del panel de inicio. */
    public record Resumen(BigDecimal vendidoHoy, int ventasHoy, int lotesPorVencer, int lotesVencidos,
                          int medicamentos, int clientes) {}
}
