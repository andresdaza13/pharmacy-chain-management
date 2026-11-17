package com.farmacia.repository;

import lombok.RequiredArgsConstructor;
import com.farmacia.despacho.DespachadorProcedimientos;
import com.farmacia.despacho.Operacion;
import com.farmacia.model.Categoria;
import com.farmacia.model.Medicamento;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

/**
 * Implementación con JdbcTemplate (PATRÓN TEMPLATE METHOD de Spring).
 * Lee con SELECT y escribe llamando a los procedimientos de pkg_inventario.
 */
@RequiredArgsConstructor
@Repository
public class MedicamentoJdbcRepository implements MedicamentoRepository {

    private static final String SELECT_BASE = """
            SELECT m.id_medicamento, m.nombre_comercial, m.nombre_generico, m.presentacion, m.id_categoria, c.descripcion,
                   m.precio_unitario, m.requiere_receta
              FROM Medicamento m
              JOIN Categoria c ON c.id_categoria = m.id_categoria
            """;

    private static final RowMapper<Medicamento> MAPPER = (rs, fila) -> new Medicamento(
            rs.getInt("id_medicamento"),
            rs.getString("nombre_comercial"),
            rs.getString("nombre_generico"),
            rs.getString("presentacion"),
            rs.getInt("id_categoria"),
            rs.getString("descripcion"),
            rs.getBigDecimal("precio_unitario"),
            "S".equals(rs.getString("requiere_receta")));

    private final JdbcTemplate jdbc;
    private final DespachadorProcedimientos despachador;

    // INYECCIÓN DE DEPENDENCIAS: Spring entrega el JdbcTemplate ya configurado.

    @Override
    public List<Medicamento> buscarPorNombre(String filtro) {
        return jdbc.query(SELECT_BASE
                + " WHERE UPPER(m.nombre_comercial || ' ' || m.nombre_generico) LIKE UPPER(?) ORDER BY m.id_medicamento",
                MAPPER, "%" + filtro.trim() + "%");
    }

    @Override
    public Optional<Medicamento> buscarPorId(int id) {
        return jdbc.query(SELECT_BASE + " WHERE m.id_medicamento = ?", MAPPER, id)
                .stream().findFirst();
    }

    @Override
    public List<Categoria> listarCategorias() {
        return jdbc.query("SELECT id_categoria, descripcion FROM Categoria ORDER BY descripcion",
                (rs, fila) -> new Categoria(rs.getInt("id_categoria"), rs.getString("descripcion")));
    }

    @Override
    public int crear(String nombre, String generico, String presentacion, int idCategoria,
                     BigDecimal precio, boolean requiereReceta) {
        return despachador.ejecutar(Operacion.MEDICAMENTO_CREAR,
                nombre, generico, presentacion, idCategoria, precio, requiereReceta ? "S" : "N");
    }

    @Override
    public void actualizar(int id, String nombre, String generico, String presentacion, int idCategoria,
                           BigDecimal precio, boolean requiereReceta) {
        despachador.ejecutar(Operacion.MEDICAMENTO_ACTUALIZAR,
                id, nombre, generico, presentacion, idCategoria, precio, requiereReceta ? "S" : "N");
    }

    @Override
    public void eliminar(int id) {
        despachador.ejecutar(Operacion.MEDICAMENTO_ELIMINAR, id);
    }
}
