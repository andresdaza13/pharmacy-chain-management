package com.farmacia.repository;

import lombok.RequiredArgsConstructor;
import com.farmacia.despacho.DespachadorProcedimientos;
import com.farmacia.despacho.Operacion;
import com.farmacia.model.Proveedor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/** Lee con SELECT y escribe con pkg_mantenimiento. (Tu tabla Proveedor no tiene teléfono.) */
@RequiredArgsConstructor
@Repository
public class ProveedorRepository {

    private static final String SELECT_BASE =
            "SELECT id_proveedor, nit, nombre, direccion FROM Proveedor ";

    private static final RowMapper<Proveedor> MAPPER = (rs, fila) -> new Proveedor(
            rs.getInt("id_proveedor"), rs.getString("nit"), rs.getString("nombre"),
            rs.getString("direccion"));

    private final JdbcTemplate jdbc;
    private final DespachadorProcedimientos despachador;


    public List<Proveedor> buscar(String filtro) {
        return jdbc.query(SELECT_BASE
                + "WHERE UPPER(nombre || ' ' || nit) LIKE UPPER(?) ORDER BY id_proveedor",
                MAPPER, "%" + filtro.trim() + "%");
    }

    public Optional<Proveedor> buscarPorId(int id) {
        return jdbc.query(SELECT_BASE + "WHERE id_proveedor = ?", MAPPER, id).stream().findFirst();
    }

    public int crear(String nit, String nombre, String direccion) {
        return despachador.ejecutar(Operacion.PROVEEDOR_CREAR, nit, nombre, direccion);
    }

    public void actualizar(int id, String nit, String nombre, String direccion) {
        despachador.ejecutar(Operacion.PROVEEDOR_ACTUALIZAR, id, nit, nombre, direccion);
    }

    public void eliminar(int id) {
        despachador.ejecutar(Operacion.PROVEEDOR_ELIMINAR, id);
    }
}
