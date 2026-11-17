package com.farmacia.controller;

import lombok.RequiredArgsConstructor;
import com.farmacia.exception.MensajesBd;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.VentaForm;
import com.farmacia.model.VentaVista;
import com.farmacia.seguridad.UsuarioFarmacia;
import com.farmacia.service.CatalogoService;
import com.farmacia.service.VentaService;
import jakarta.validation.Valid;
import org.springframework.dao.DataAccessException;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;

@RequiredArgsConstructor
@Controller
@RequestMapping("/ventas")
public class VentaController {

    private final VentaService servicio;
    private final CatalogoService catalogo;


    /** Ventas del día (solo administrador). Por defecto, hoy; con ?todas=true se ven todas. */
    @GetMapping
    public String listar(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fecha,
                         @RequestParam(defaultValue = "false") boolean todas,
                         @AuthenticationPrincipal UsuarioFarmacia usuario, Model model) {
        LocalDate dia = todas ? null : (fecha != null ? fecha : LocalDate.now());
        List<VentaVista> lista = servicio.listar(dia, usuario);
        // Las anuladas se muestran (historial) pero no suman
        BigDecimal total = lista.stream().filter(v -> !v.anulada())
                .map(VentaVista::total).reduce(BigDecimal.ZERO, BigDecimal::add);
        model.addAttribute("ventas", lista);
        model.addAttribute("fecha", dia);
        model.addAttribute("fechaTexto", dia == null ? "Todas las fechas"
                : dia.format(DateTimeFormatter.ofPattern("EEEE d 'de' MMMM 'de' yyyy", Locale.forLanguageTag("es-CO"))));
        model.addAttribute("cantidad", lista.stream().filter(v -> !v.anulada()).count());
        model.addAttribute("totalVendido", total);
        return "ventas/lista";
    }

    @GetMapping("/nuevo")
    public String nuevo(@AuthenticationPrincipal UsuarioFarmacia usuario, Model model) {
        model.addAttribute("form", new VentaForm());
        cargarListas(model, usuario);
        return "ventas/form";
    }

    @GetMapping("/{id}")
    public String ver(@PathVariable int id, Model model, RedirectAttributes ra) {
        try {
            model.addAttribute("venta", servicio.obtener(id));
            model.addAttribute("lineas", servicio.lineas(id));
            return "ventas/detalle";
        } catch (ReglaNegocioException ex) {
            ra.addFlashAttribute("error", ex.getMessage());
            return "redirect:/ventas";
        }
    }

    @PostMapping("/guardar")
    public String guardar(@AuthenticationPrincipal UsuarioFarmacia usuario,
                          @Valid @ModelAttribute("form") VentaForm form,
                          BindingResult resultado, Model model, RedirectAttributes ra) {
        if (resultado.hasErrors()) {
            cargarListas(model, usuario);
            return "ventas/form";
        }
        try {
            int id = servicio.registrar(form, usuario);
            ra.addFlashAttribute("ok", "Venta #" + id + " registrada. Oracle descontó el stock de los lotes (FEFO).");
            return "redirect:/ventas/" + id;
        } catch (DataAccessException | ReglaNegocioException ex) {
            model.addAttribute("error", MensajesBd.de(ex));
            cargarListas(model, usuario);
            return "ventas/form";
        }
    }

    @PostMapping("/{id}/anular")
    public String anular(@PathVariable int id, RedirectAttributes ra) {
        try {
            servicio.anular(id);
            ra.addFlashAttribute("ok", "Venta anulada: el stock volvió a los lotes y la venta queda en el historial.");
        } catch (DataAccessException | ReglaNegocioException ex) {
            ra.addFlashAttribute("error", MensajesBd.de(ex));
        }
        return "redirect:/ventas";
    }

    private static Integer idEmpleado(UsuarioFarmacia usuario) {
        return usuario == null ? null : usuario.getIdEmpleado();
    }

    private void cargarListas(Model model, UsuarioFarmacia usuario) {
        Integer idEmpleado = idEmpleado(usuario);
        Integer idSucursal = usuario == null ? null : usuario.getIdSucursal();
        model.addAttribute("clientes", catalogo.clientes());
        model.addAttribute("metodos", catalogo.metodosPago());
        model.addAttribute("medicamentos", catalogo.medicamentosParaVenta(idSucursal));
        if (idEmpleado != null) {
            model.addAttribute("empleadoFijo", catalogo.etiquetaEmpleado(idEmpleado).orElse("Empleado " + idEmpleado));
        } else {
            model.addAttribute("empleados", catalogo.empleados());
        }
    }
}
