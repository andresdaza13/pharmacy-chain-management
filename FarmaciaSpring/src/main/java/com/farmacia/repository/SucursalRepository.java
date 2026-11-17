package com.farmacia.repository;

import com.farmacia.despacho.DespachadorProcedimientos;
import com.farmacia.despacho.Operacion;
import com.farmacia.model.Opcion;
import com.farmacia.model.Sucursal;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/** Lectura con SELECT; escritura con pkg_sucursales (08_requisitos_proyecto.sql). */
@Repository
@RequiredArgsConstructor
public class SucursalRepository {

    private static final String SELECT_BASE = """
            SELECT s.id_sucursal, s.nombre, s.direccion, s.id_ciudad, c.nombre AS ciudad,
                   (SELECT COUNT(*) FROM Empleado e WHERE e.id_sucursal = s.id_sucursal) AS empleados,
                   (SELECT COUNT(*) FROM Lote l     WHERE l.id_sucursal = s.id_sucursal) AS lotes,
                   (SELECT COUNT(*) FROM Venta v    WHERE v.id_sucursal = s.id_sucursal) AS ventas
              FROM Sucursal s
              JOIN Ciudad c ON c.id_ciudad = s.id_ciudad
            """;

    private static final RowMapper<Sucursal> MAPPER = (rs, i) -> new Sucursal(
            rs.getInt("id_sucursal"), rs.getString("nombre"), rs.getString("direccion"),
            rs.getInt("id_ciudad"), rs.getString("ciudad"),
            rs.getInt("empleados"), rs.getInt("lotes"), rs.getInt("ventas"));

    private final JdbcTemplate jdbc;
    private final DespachadorProcedimientos despachador;

    public List<Sucursal> listar() {
        return jdbc.query(SELECT_BASE + " ORDER BY c.nombre, s.nombre", MAPPER);
    }

    public Optional<Sucursal> buscarPorId(int id) {
        return jdbc.query(SELECT_BASE + " WHERE s.id_sucursal = ?", MAPPER, id).stream().findFirst();
    }

    public List<Opcion> ciudades() {
        return jdbc.query("SELECT id_ciudad, nombre FROM Ciudad ORDER BY nombre",
                (rs, i) -> new Opcion(rs.getInt(1), rs.getString(2)));
    }

    public int obtenerOCrearCiudad(String nombre) {
        return despachador.ejecutar(Operacion.CIUDAD_OBTENER_O_CREAR, nombre);
    }

    public int crear(String nombre, String direccion, int idCiudad) {
        return despachador.ejecutar(Operacion.SUCURSAL_CREAR, nombre, direccion, idCiudad);
    }

    public void actualizar(int id, String nombre, String direccion, int idCiudad) {
        despachador.ejecutar(Operacion.SUCURSAL_ACTUALIZAR, id, nombre, direccion, idCiudad);
    }

    public void eliminar(int id) {
        despachador.ejecutar(Operacion.SUCURSAL_ELIMINAR, id);
    }
}
