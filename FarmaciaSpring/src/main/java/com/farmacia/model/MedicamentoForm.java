package com.farmacia.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;

/** PATRÓN DTO: objeto que viaja entre el formulario HTML y el controlador, con validaciones. */
@Data
public class MedicamentoForm {
    private Integer id;
    @NotBlank(message = "El nombre es obligatorio")
    @Size(max = 150, message = "Máximo 150 caracteres")
    private String nombre;
    @NotBlank(message = "El nombre genérico es obligatorio")
    @Size(max = 150, message = "Máximo 150 caracteres")
    private String nombreGenerico;
    @NotBlank(message = "La presentación es obligatoria")
    @Size(max = 100, message = "Máximo 100 caracteres")
    private String presentacion;
    @NotNull(message = "Selecciona una categoría")
    private Integer idCategoria;
    @NotNull(message = "El precio es obligatorio")
    @PositiveOrZero(message = "El precio no puede ser negativo")
    private BigDecimal precio;
    private boolean requiereReceta;

    public static MedicamentoForm desde(Medicamento m) {
        MedicamentoForm f = new MedicamentoForm();
        f.setId(m.id()); f.setNombre(m.nombre()); f.setIdCategoria(m.idCategoria());
        f.setNombreGenerico(m.nombreGenerico()); f.setPresentacion(m.presentacion());
        f.setPrecio(m.precio()); f.setRequiereReceta(m.requiereReceta());
        return f;
    }
}
