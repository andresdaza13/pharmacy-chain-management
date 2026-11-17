package com.farmacia.repository;

import lombok.RequiredArgsConstructor;
import com.farmacia.model.MedicamentoVenta;
import com.farmacia.model.Opcion;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Listas para los desplegables de los formularios (sucursales, proveedores, etc.). */
@RequiredArgsConstructor
@Repository
public class CatalogoRepository {

    private static final RowMapper<Opcion> MAPPER =
            (rs, fila) -> new Opcion(rs.getInt(1), rs.getString(2));

    private final JdbcTemplate jdbc;


    public List<Opcion> sucursales() {
        return jdbc.query("SELECT id_sucursal, nombre FROM Sucursal ORDER BY nombre", MAPPER);
    }

    public List<Opcion> proveedores() {
        return jdbc.query("SELECT id_proveedor, nombre FROM Proveedor ORDER BY nombre", MAPPER);
    }

    public List<Opcion> medicamentos() {
        return jdbc.query("SELECT id_medicamento, nombre_comercial FROM Medicamento ORDER BY nombre_comercial", MAPPER);
    }

    public List<Opcion> empleados() {
        return jdbc.query("""
                SELECT e.id_empleado, p.nombre || ' ' || p.apellido
                  FROM Empleado e JOIN Persona p ON p.id_persona = e.id_empleado
                 ORDER BY p.nombre, p.apellido""", MAPPER);
    }

    /** "Ana Pérez — Sucursal Centro (REGENTE)": para elegir quién recibe un traslado. */
    public List<Opcion> empleadosConSucursal() {
        return jdbc.query("""
                SELECT e.id_empleado, p.nombre || ' ' || p.apellido || ' — ' || s.nombre || ' (' || e.cargo || ')'
                  FROM Empleado e
                  JOIN Persona p  ON p.id_persona  = e.id_empleado
                  JOIN Sucursal s ON s.id_sucursal = e.id_sucursal
                 ORDER BY s.nombre, p.nombre""", MAPPER);
    }

    public List<Opcion> clientes() {
        return jdbc.query("""
                SELECT c.id_cliente, p.nombre || ' ' || p.apellido
                  FROM Cliente c JOIN Persona p ON p.id_persona = c.id_cliente
                 ORDER BY p.nombre, p.apellido""", MAPPER);
    }

    /**
     * Medicamentos con stock vendible (lotes no vencidos y con unidades). Si se conoce la sucursal
     * solo cuenta el stock de esa sucursal; si es null, el stock total.
     */
    public List<MedicamentoVenta> medicamentosParaVenta(Integer idSucursal) {
        String base = """
                SELECT m.id_medicamento, m.nombre_comercial, m.precio_unitario, m.requiere_receta,
                       SUM(l.cantidad_actual) AS stock
                  FROM Medicamento m
                  JOIN Lote l ON l.id_medicamento = m.id_medicamento
                 WHERE l.cantidad_actual > 0 AND l.fecha_vencimiento > TRUNC(SYSDATE)  -- igual que trg_venta_lote_bi
                """;
        String fin = """
                 GROUP BY m.id_medicamento, m.nombre_comercial, m.precio_unitario, m.requiere_receta
                 ORDER BY m.nombre_comercial""";
        RowMapper<MedicamentoVenta> mapper = (rs, fila) -> new MedicamentoVenta(
                rs.getInt("id_medicamento"), rs.getString("nombre_comercial"), rs.getBigDecimal("precio_unitario"),
                "S".equals(rs.getString("requiere_receta")), rs.getInt("stock"));
        if (idSucursal == null) return jdbc.query(base + fin, mapper);
        return jdbc.query(base + " AND l.id_sucursal = ? " + fin, mapper, idSucursal);
    }

    /** Ej. "Ana Pérez — Sucursal Centro". */
    public Optional<String> etiquetaEmpleado(int idEmpleado) {
        return jdbc.queryForList("""
                SELECT p.nombre || ' ' || p.apellido || ' — ' || s.nombre
                  FROM Empleado e
                  JOIN Persona p  ON p.id_persona  = e.id_empleado
                  JOIN Sucursal s ON s.id_sucursal = e.id_sucursal
                 WHERE e.id_empleado = ?""", String.class, idEmpleado).stream().findFirst();
    }

    /** Métodos de pago que acepta el CHECK de Venta.metodo_pago (EFECTIVO, TARJETA, TRANSFERENCIA). */
    public List<String> metodosPago() {
        return valoresPermitidos("VENTA", "METODO_PAGO", List.of("EFECTIVO", "TARJETA", "TRANSFERENCIA"));
    }

    /** Cargos que acepta el CHECK de Empleado.cargo (VENDEDOR, REGENTE, ADMINISTRADOR...). */
    public List<String> cargos() {
        return valoresPermitidos("EMPLEADO", "CARGO", List.of("VENDEDOR", "REGENTE", "ADMINISTRADOR"));
    }

    /**
     * Lee de user_constraints la restricción CHECK de una columna (p. ej. cargo IN ('VENDEDOR','REGENTE'))
     * y extrae los textos entre comillas. Así la app usa EXACTAMENTE los valores de la base de datos
     * y no hay que repetirlos en Java. Si no se pueden leer, usa la lista por defecto.
     */
    public List<String> valoresPermitidos(String tabla, String columna, List<String> porDefecto) {
        List<String> valores = new ArrayList<>();
        try {
            List<String> condiciones = jdbc.query(
                    "SELECT search_condition_vc FROM user_constraints WHERE table_name = ? AND constraint_type = 'C'",
                    (rs, fila) -> rs.getString(1), tabla);
            Pattern literal = Pattern.compile("'([^']+)'");
            for (String c : condiciones) {
                if (c != null && c.toUpperCase().contains(columna) && c.toUpperCase().contains(" IN ")) {
                    Matcher m = literal.matcher(c);
                    while (m.find()) if (!valores.contains(m.group(1))) valores.add(m.group(1));
                }
            }
        } catch (RuntimeException ex) {
            // se usa la lista por defecto
        }
        return valores.isEmpty() ? porDefecto : valores;
    }
}
