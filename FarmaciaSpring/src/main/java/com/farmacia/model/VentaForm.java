package com.farmacia.model;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.ArrayList;
import java.util.List;

/**
 * DTO de la venta nueva: cliente, método de pago y una lista de líneas (medicamento + cantidad).
 * El total NO se escribe: lo va sumando Oracle (trigger trg_venta_lote_ai del equipo).
 * Si algún medicamento requiere receta, se piden los datos del médico.
 */
@Data
public class VentaForm {
    private Integer idCliente;
    private Integer idEmpleado;
    @NotBlank(message = "Selecciona el método de pago")
    private String metodoPago;
    private String nombreMedico;
    private String registroMedico;
    private List<LineaVenta> lineas = new ArrayList<>(List.of(new LineaVenta()));
}
