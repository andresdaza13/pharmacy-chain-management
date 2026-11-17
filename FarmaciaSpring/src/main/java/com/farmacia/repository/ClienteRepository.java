package com.farmacia.repository;

import com.farmacia.model.Cliente;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * PACIENTES. Todo se hace sobre la VISTA vw_pacientes (08_requisitos_proyecto.sql).
 *
 * Una vista con JOIN no se puede modificar directamente. El trigger INSTEAD OF trg_pacientes_instead
 * intercepta el INSERT / UPDATE / DELETE y lo traduce a los paquetes:
 *   INSERT -> pkg_personas.registrar_persona('C', ...)   (Persona + Cliente + Teléfono)
 *   UPDATE -> pkg_mantenimiento.actualizar_cliente       (+ cambio de teléfono)
 *   DELETE -> pkg_mantenimiento.eliminar_cliente
 * Desde Java parece una tabla normal: así se demuestra el trigger INSTEAD OF en la aplicación.
 */
@Repository
@RequiredArgsConstructor
public class ClienteRepository {

    private static final String SELECT_BASE = """
            SELECT id_paciente, nombre, apellido, documento, email, direccion,
                   TO_CHAR(fecha_registro, 'DD/MM/YYYY') AS registro, telefono
              FROM vw_pacientes
            """;

    private static final RowMapper<Cliente> MAPPER = (rs, fila) -> new Cliente(
            rs.getInt("id_paciente"), rs.getString("nombre"), rs.getString("apellido"),
            rs.getString("documento"), rs.getString("email"), rs.getString("direccion"),
            rs.getString("registro"), rs.getString("telefono"));

    private final JdbcTemplate jdbc;

    public List<Cliente> buscar(String filtro) {
        return jdbc.query(SELECT_BASE
                + " WHERE UPPER(nombre || ' ' || apellido || ' ' || documento) LIKE UPPER(?)"
                + " ORDER BY apellido, nombre", MAPPER, "%" + filtro.trim() + "%");
    }

    public Optional<Cliente> buscarPorId(int id) {
        return jdbc.query(SELECT_BASE + " WHERE id_paciente = ?", MAPPER, id).stream().findFirst();
    }

    public void crear(String nombre, String apellido, String documento, String email, String direccion, String telefono) {
        jdbc.update("""
                INSERT INTO vw_pacientes (nombre, apellido, documento, email, direccion, telefono)
                VALUES (?, ?, ?, ?, ?, ?)""", nombre, apellido, documento, email, direccion, telefono);
    }

    public void actualizar(int id, String nombre, String apellido, String documento, String email,
                           String direccion, String telefono) {
        jdbc.update("""
                UPDATE vw_pacientes
                   SET nombre = ?, apellido = ?, documento = ?, email = ?, direccion = ?, telefono = ?
                 WHERE id_paciente = ?""", nombre, apellido, documento, email, direccion, telefono, id);
    }

    public void eliminar(int id) {
        jdbc.update("DELETE FROM vw_pacientes WHERE id_paciente = ?", id);
    }
}
