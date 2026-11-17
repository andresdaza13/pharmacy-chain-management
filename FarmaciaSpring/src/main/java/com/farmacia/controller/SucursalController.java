package com.farmacia.controller;

import com.farmacia.exception.MensajesBd;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.SucursalForm;
import com.farmacia.service.SucursalService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/** Sucursales: todos los roles de gestión las consultan; solo el administrador las crea, edita o elimina. */
@Controller
@RequestMapping("/sucursales")
@RequiredArgsConstructor
public class SucursalController {

    private final SucursalService servicio;

    @GetMapping
    public String listar(Model model) {
        model.addAttribute("sucursales", servicio.listar());
        return "sucursales/lista";
    }

    @GetMapping("/nuevo")
    public String nuevo(Model model) {
        model.addAttribute("form", new SucursalForm());
        model.addAttribute("ciudades", servicio.ciudades());
        return "sucursales/form";
    }

    @GetMapping("/{id}/editar")
    public String editar(@PathVariable int id, Model model, RedirectAttributes ra) {
        try {
            model.addAttribute("form", SucursalForm.desde(servicio.obtener(id)));
            model.addAttribute("ciudades", servicio.ciudades());
            return "sucursales/form";
        } catch (ReglaNegocioException ex) {
            ra.addFlashAttribute("error", ex.getMessage());
            return "redirect:/sucursales";
        }
    }

    @PostMapping("/guardar")
    public String guardar(@Valid @ModelAttribute("form") SucursalForm form, BindingResult resultado,
                          Model model, RedirectAttributes ra) {
        if (!resultado.hasErrors()) {
            try {
                boolean esNueva = form.getId() == null;
                servicio.guardar(form);
                ra.addFlashAttribute("ok", esNueva ? "Sucursal creada." : "Sucursal actualizada.");
                return "redirect:/sucursales";
            } catch (DataAccessException | ReglaNegocioException ex) {
                model.addAttribute("error", MensajesBd.de(ex));
            }
        }
        model.addAttribute("ciudades", servicio.ciudades());
        return "sucursales/form";
    }

    @PostMapping("/{id}/eliminar")
    public String eliminar(@PathVariable int id, RedirectAttributes ra) {
        try {
            servicio.eliminar(id);
            ra.addFlashAttribute("ok", "Sucursal eliminada.");
        } catch (DataAccessException | ReglaNegocioException ex) {
            ra.addFlashAttribute("error", MensajesBd.de(ex));
        }
        return "redirect:/sucursales";
    }
}
