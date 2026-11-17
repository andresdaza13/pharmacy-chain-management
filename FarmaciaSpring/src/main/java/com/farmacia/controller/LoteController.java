package com.farmacia.controller;

import lombok.RequiredArgsConstructor;
import com.farmacia.exception.MensajesBd;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.LoteForm;
import com.farmacia.seguridad.UsuarioFarmacia;
import com.farmacia.service.CatalogoService;
import com.farmacia.service.LoteService;
import jakarta.validation.Valid;
import org.springframework.dao.DataAccessException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@RequiredArgsConstructor
@Controller
@RequestMapping("/lotes")
public class LoteController {

    private final LoteService servicio;
    private final CatalogoService catalogo;


    @GetMapping
    public String listar(Model model) {
        model.addAttribute("lotes", servicio.listar());
        return "lotes/lista";
    }

    @GetMapping("/nuevo")
    public String nuevo(@AuthenticationPrincipal UsuarioFarmacia usuario, Model model) {
        LoteForm form = new LoteForm();
        aplicarEmpleado(form, usuario);
        model.addAttribute("form", form);
        cargarListas(model, usuario);
        return "lotes/form";
    }

    @GetMapping("/{id}/editar")
    public String editar(@PathVariable int id, Model model, RedirectAttributes ra) {
        try {
            model.addAttribute("form", servicio.obtener(id));
            return "lotes/form";
        } catch (ReglaNegocioException ex) {
            ra.addFlashAttribute("error", ex.getMessage());
            return "redirect:/lotes";
        }
    }

    @PostMapping("/guardar")
    public String guardar(@AuthenticationPrincipal UsuarioFarmacia usuario,
                          @Valid @ModelAttribute("form") LoteForm form,
                          BindingResult resultado, Model model, RedirectAttributes ra) {
        if (form.getId() == null) aplicarEmpleado(form, usuario); // no se confía en lo que venga del formulario
        if (resultado.hasErrors()) {
            cargarListas(model, usuario);
            return "lotes/form";
        }
        try {
            boolean esNuevo = form.getId() == null;
            servicio.guardar(form);
            ra.addFlashAttribute("ok", esNuevo ? "Lote creado correctamente." : "Lote actualizado correctamente.");
            return "redirect:/lotes";
        } catch (DataAccessException | ReglaNegocioException ex) {
            model.addAttribute("error", MensajesBd.de(ex));
            cargarListas(model, usuario);
            return "lotes/form";
        }
    }

    @PostMapping("/{id}/eliminar")
    public String eliminar(@PathVariable int id, RedirectAttributes ra) {
        try {
            servicio.eliminar(id);
            ra.addFlashAttribute("ok", "Lote eliminado.");
        } catch (DataAccessException | ReglaNegocioException ex) {
            ra.addFlashAttribute("error", MensajesBd.de(ex));
        }
        return "redirect:/lotes";
    }

    @GetMapping("/{id}/trasladar")
    public String trasladar(@PathVariable int id, Model model, RedirectAttributes ra) {
        try {
            model.addAttribute("lote", servicio.vista(id));
            model.addAttribute("sucursales", catalogo.sucursales());
            model.addAttribute("empleados", catalogo.empleadosConSucursal());
            return "lotes/trasladar";
        } catch (ReglaNegocioException ex) {
            ra.addFlashAttribute("error", ex.getMessage());
            return "redirect:/lotes";
        }
    }

    @PostMapping("/{id}/trasladar")
    public String confirmarTraslado(@PathVariable int id, @RequestParam(required = false) Integer idSucursalDestino,
                                    @RequestParam(required = false) Integer cantidad,
                                    @RequestParam(required = false) Integer idEmpleado, RedirectAttributes ra) {
        try {
            int nuevo = servicio.trasladar(id, idSucursalDestino, cantidad, idEmpleado);
            ra.addFlashAttribute("ok", "Traslado confirmado (COMMIT): se creó el lote " + nuevo + " en la sucursal de destino.");
            return "redirect:/lotes";
        } catch (DataAccessException | ReglaNegocioException ex) {
            ra.addFlashAttribute("error", "Traslado cancelado (ROLLBACK): " + MensajesBd.de(ex));
            return "redirect:/lotes/" + id + "/trasladar";
        }
    }

    /**
     * MER: el empleado registra el lote y pertenece a una sucursal. Si el usuario está ligado a un empleado,
     * el lote se registra a su nombre y en su sucursal.
     */
    private static void aplicarEmpleado(LoteForm form, UsuarioFarmacia usuario) {
        if (usuario != null && usuario.ligadoAEmpleado()) {
            form.setIdEmpleado(usuario.getIdEmpleado());
            form.setIdSucursal(usuario.getIdSucursal());
        }
    }

    private void cargarListas(Model model, UsuarioFarmacia usuario) {
        boolean fijo = usuario != null && usuario.ligadoAEmpleado();
        model.addAttribute("fijo", fijo);
        if (fijo) {
            model.addAttribute("empleadoFijo",
                    catalogo.etiquetaEmpleado(usuario.getIdEmpleado()).orElse("Empleado " + usuario.getIdEmpleado()));
        } else {
            model.addAttribute("sucursales", catalogo.sucursales());
            model.addAttribute("empleados", catalogo.empleados());
        }
        model.addAttribute("medicamentos", catalogo.medicamentos());
        model.addAttribute("proveedores", catalogo.proveedores());
    }
}
