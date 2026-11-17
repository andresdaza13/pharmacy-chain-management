package com.farmacia.service;

import com.farmacia.despacho.Rol;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.LineaDetalle;
import com.farmacia.model.LineaVenta;
import com.farmacia.model.Medicamento;
import com.farmacia.model.VentaForm;
import com.farmacia.model.VentaVista;
import com.farmacia.repository.MedicamentoRepository;
import com.farmacia.repository.VentaDetalleRepository;
import com.farmacia.repository.VentaRepository;
import com.farmacia.seguridad.UsuarioFarmacia;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * LÓGICA DE LA VENTA.
 * Reparto de responsabilidades (tres capas que se complementan):
 *   - JAVA (aquí):  arma el pedido, valida lo que depende del USUARIO de la app
 *                   (p. ej. solo un regente autoriza receta) y da mensajes claros.
 *   - PAQUETE:      pkg_ventas (del equipo): registrar_venta crea la cabecera y
 *                   agregar_medicamento reparte cada línea entre lotes (FEFO).
 *   - TRIGGERS:     trg_venta_bi, trg_venta_lote_bi y trg_venta_lote_ai validan y mueven el stock.
 */
@Service
@RequiredArgsConstructor
public class VentaService {

    private final VentaRepository ventas;
    private final VentaDetalleRepository detalle;
    private final MedicamentoRepository medicamentos;

    /** Un usuario ligado a una sucursal (que no sea admin/gerencia/auditor) solo ve las ventas de su sucursal. */
    public List<VentaVista> listar(LocalDate fecha, UsuarioFarmacia usuario) {
        boolean global = usuario == null || usuario.tiene(Rol.ADMIN) || usuario.tiene(Rol.GERENCIA)
                || usuario.tiene(Rol.AUDITOR);
        return ventas.listar(fecha, global ? null : usuario.getIdSucursal());
    }

    public VentaVista obtener(int id) {
        return ventas.buscarPorId(id)
                .orElseThrow(() -> new ReglaNegocioException("No existe la venta con ID " + id));
    }

    public List<LineaDetalle> lineas(int idVenta) {
        return detalle.detalle(idVenta);
    }

    /** @return el ID de la venta creada */
    @Transactional
    public int registrar(VentaForm f, UsuarioFarmacia usuario) {
        Integer idEmpleado = usuario != null && usuario.ligadoAEmpleado() ? usuario.getIdEmpleado() : f.getIdEmpleado();
        if (f.getIdCliente() == null) throw new ReglaNegocioException("Selecciona el cliente.");
        if (idEmpleado == null) throw new ReglaNegocioException("Selecciona el empleado que atiende.");

        // Líneas: se ignoran las vacías y se suman las repetidas del mismo medicamento
        Map<Integer, Integer> pedido = new LinkedHashMap<>();
        for (LineaVenta l : f.getLineas()) {
            if (l.getIdMedicamento() == null) continue;
            if (l.getCantidad() == null || l.getCantidad() <= 0) {
                throw new ReglaNegocioException("Cada medicamento debe tener una cantidad mayor que cero.");
            }
            pedido.merge(l.getIdMedicamento(), l.getCantidad(), Integer::sum);
        }
        if (pedido.isEmpty()) throw new ReglaNegocioException("Agrega al menos un medicamento.");

        // Regla del documento: el REGENTE autoriza las ventas con receta médica.
        boolean llevaReceta = pedido.keySet().stream()
                .map(id -> medicamentos.buscarPorId(id).map(Medicamento::requiereReceta).orElse(false))
                .anyMatch(Boolean::booleanValue);
        if (llevaReceta && usuario != null && !usuario.tiene(Rol.REGENTE) && !usuario.tiene(Rol.ADMIN)) {
            throw new ReglaNegocioException(
                    "La venta incluye medicamentos con receta: debe autorizarla un regente farmacéutico.");
        }

        String medico = vacioANull(f.getNombreMedico());
        String registro = vacioANull(f.getRegistroMedico());
        if ((medico == null) != (registro == null)) {   // CHECK de Venta: los dos o ninguno
            throw new ReglaNegocioException("Escribe el nombre del médico y su registro, o deja los dos vacíos.");
        }
        int idSucursal = ventas.sucursalDeEmpleado(idEmpleado)
                .orElseThrow(() -> new ReglaNegocioException("El empleado no existe o no tiene sucursal."));

        // Paso 1: cabecera.  Paso 2: un agregar_medicamento por línea.
        // Todo va en la MISMA transacción (@Transactional): si una línea falla (sin stock, sin receta...),
        // Spring hace ROLLBACK y no queda ni la cabecera ni las líneas anteriores.
        int idVenta = ventas.crearCabecera(f.getIdCliente(), idEmpleado, idSucursal,
                f.getMetodoPago().trim(), medico, registro);
        for (Map.Entry<Integer, Integer> linea : pedido.entrySet()) {
            ventas.agregarMedicamento(idVenta, linea.getKey(), linea.getValue());
        }
        return idVenta;
    }

    @Transactional
    public void anular(int idVenta) {
        ventas.anular(idVenta);
    }

    private static String vacioANull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
