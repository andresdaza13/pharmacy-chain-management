package com.farmacia.repository;

import lombok.RequiredArgsConstructor;
import com.farmacia.despacho.DespachadorProcedimientos;
import com.farmacia.despacho.Operacion;
import com.farmacia.model.Empleado;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@RequiredArgsConstructor
@Repository
public class EmpleadoRepository {

    private static final String SELECT_BASE = """
            SELECT e.id_empleado, p.nombre, p.apellido, p.documento, p.email,
                   e.cargo, e.salario, e.id_sucursal, s.nombre AS sucursal
              FROM Empleado e
              JOIN Persona p  ON p.id_persona  = e.id_empleado
              JOIN Sucursal s ON s.id_sucursal = e.id_sucursal
            """;

    private static final RowMapper<Empleado> MAPPER = (rs, fila) -> new Empleado(
            rs.getInt("id_empleado"), rs.getString("nombre"), rs.getString("apellido"),
            rs.getString("documento"), rs.getString("email"), rs.getString("cargo"),
            rs.getBigDecimal("salario"), rs.getInt("id_sucursal"), rs.getString("sucursal"));

    private final JdbcTemplate jdbc;
    private final DespachadorProcedimientos despachador;


    public List<Empleado> buscar(String filtro) {
        return jdbc.query(SELECT_BASE
                + " WHERE UPPER(p.nombre || ' ' || p.apellido || ' ' || p.documento) LIKE UPPER(?)"
                + " ORDER BY e.id_empleado", MAPPER, "%" + filtro.trim() + "%");
    }

    public Optional<Empleado> buscarPorId(int id) {
        return jdbc.query(SELECT_BASE + " WHERE e.id_empleado = ?", MAPPER, id).stream().findFirst();
    }

    public int crear(String nombre, String apellido, String documento, String email,
                     String cargo, BigDecimal salario, int idSucursal) {
        // pkg_personas.registrar_persona (del equipo): Persona + Empleado. 'E' = empleado.
        return despachador.ejecutar(Operacion.REGISTRAR_PERSONA, "E", nombre, apellido, documento, email,
                null, null, cargo, salario, idSucursal);
    }

    public void actualizar(int id, String nombre, String apellido, String documento, String email,
                           String cargo, BigDecimal salario, int idSucursal) {
        despachador.ejecutar(Operacion.EMPLEADO_ACTUALIZAR,
                id, nombre, apellido, documento, email, cargo, salario, idSucursal);
    }

    public void eliminar(int id) {
        despachador.ejecutar(Operacion.EMPLEADO_ELIMINAR, id);
    }
}
