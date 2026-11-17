package com.farmacia.model;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import lombok.Data;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.LocalDate;

/** Al crear se eligen medicamento, sucursal, proveedor y empleado; al editar solo fechas y cantidad actual. */
@Data
public class LoteForm {
    private Integer id;
    private Integer idMedicamento;
    private Integer idSucursal;
    private Integer idProveedor;
    private Integer idEmpleado;
    @NotNull(message = "La fecha de fabricación es obligatoria")
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate fechaFabricacion;
    @NotNull(message = "La fecha de vencimiento es obligatoria")
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate fechaVencimiento;
    @NotNull(message = "La cantidad es obligatoria")
    @PositiveOrZero(message = "La cantidad no puede ser negativa")
    private Integer cantidad;
}
