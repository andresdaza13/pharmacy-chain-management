package com.farmacia.controller;

import lombok.RequiredArgsConstructor;
import com.farmacia.exception.MensajesBd;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.ProveedorForm;
import com.farmacia.service.ProveedorService;
import jakarta.validation.Valid;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@RequiredArgsConstructor
@Controller
@RequestMapping("/proveedores")
public class ProveedorController {

    private final ProveedorService servicio;

    @GetMapping
    public String listar(@RequestParam(name = "q", defaultValue = "") String q, Model model) {
        model.addAttribute("proveedores", servicio.listar(q));
        model.addAttribute("q", q);
        return "proveedores/lista";
    }

    @GetMapping("/nuevo")
    public String nuevo(Model model) {
        model.addAttribute("form", new ProveedorForm());
        return "proveedores/form";
    }

    @GetMapping("/{id}/editar")
    public String editar(@PathVariable int id, Model model, RedirectAttributes ra) {
        try {
            model.addAttribute("form", ProveedorForm.desde(servicio.obtener(id)));
            return "proveedores/form";
        } catch (ReglaNegocioException ex) {
            ra.addFlashAttribute("error", ex.getMessage());
            return "redirect:/proveedores";
        }
    }

    @PostMapping("/guardar")
    public String guardar(@Valid @ModelAttribute("form") ProveedorForm form,
                          BindingResult resultado, Model model, RedirectAttributes ra) {
        if (resultado.hasErrors()) {
            return "proveedores/form";
        }
        try {
            boolean esNuevo = form.getId() == null;
            servicio.guardar(form);
            ra.addFlashAttribute("ok", esNuevo ? "Proveedor creado correctamente." : "Proveedor actualizado correctamente.");
            return "redirect:/proveedores";
        } catch (DataAccessException | ReglaNegocioException ex) {
            model.addAttribute("error", MensajesBd.de(ex));
            return "proveedores/form";
        }
    }

    @PostMapping("/{id}/eliminar")
    public String eliminar(@PathVariable int id, RedirectAttributes ra) {
        try {
            servicio.eliminar(id);
            ra.addFlashAttribute("ok", "Proveedor eliminado.");
        } catch (DataAccessException | ReglaNegocioException ex) {
            ra.addFlashAttribute("error", MensajesBd.de(ex));
        }
        return "redirect:/proveedores";
    }
}
