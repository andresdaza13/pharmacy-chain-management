package com.farmacia.repository;

import com.farmacia.model.Categoria;
import com.farmacia.model.Medicamento;
import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

/** PATRÓN REPOSITORY / DAO: contrato de acceso a datos, independiente de la tecnología. */
public interface MedicamentoRepository {
    List<Medicamento> buscarPorNombre(String filtro);
    Optional<Medicamento> buscarPorId(int id);
    List<Categoria> listarCategorias();
    int crear(String nombre, String generico, String presentacion, int idCategoria, BigDecimal precio, boolean requiereReceta);
    void actualizar(int id, String nombre, String generico, String presentacion, int idCategoria, BigDecimal precio, boolean requiereReceta);
    void eliminar(int id);
}
