package com.farmacia.controller;

import lombok.RequiredArgsConstructor;
import com.farmacia.exception.MensajesBd;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.ClienteForm;
import com.farmacia.service.ClienteService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@RequiredArgsConstructor
@Controller
@RequestMapping("/clientes")
public class ClienteController {

    private final ClienteService servicio;

    @GetMapping
    public String listar(@RequestParam(name = "q", defaultValue = "") String q, Model model) {
        model.addAttribute("clientes", servicio.listar(q));
        model.addAttribute("q", q);
        return "clientes/lista";
    }

    @GetMapping("/nuevo")
    public String nuevo(Model model) {
        model.addAttribute("form", new ClienteForm());
        return "clientes/form";
    }

    @GetMapping("/{id}/editar")
    public String editar(@PathVariable int id, Model model, RedirectAttributes ra) {
        try {
            model.addAttribute("form", ClienteForm.desde(servicio.obtener(id)));
            return "clientes/form";
        } catch (ReglaNegocioException ex) {
            ra.addFlashAttribute("error", ex.getMessage());
            return "redirect:/clientes";
        }
    }

    @PostMapping("/guardar")
    public String guardar(@Valid @ModelAttribute("form") ClienteForm form,
                          BindingResult resultado, Model model, RedirectAttributes ra,
                          HttpServletRequest request) {
        if (resultado.hasErrors()) {
            return "clientes/form";
        }
        try {
            boolean esNuevo = form.getId() == null;
            servicio.guardar(form);
            ra.addFlashAttribute("ok", esNuevo ? "Paciente registrado correctamente." : "Paciente actualizado correctamente.");
            return (request.isUserInRole("ADMIN") || request.isUserInRole("ADMIN_SUCURSAL")) ? "redirect:/clientes" : "redirect:/ventas/nuevo";
        } catch (DataAccessException | ReglaNegocioException ex) {
            model.addAttribute("error", MensajesBd.de(ex));
            return "clientes/form";
        }
    }

    @PostMapping("/{id}/eliminar")
    public String eliminar(@PathVariable int id, RedirectAttributes ra) {
        try {
            servicio.eliminar(id);
            ra.addFlashAttribute("ok", "Paciente eliminado.");
        } catch (DataAccessException | ReglaNegocioException ex) {
            ra.addFlashAttribute("error", MensajesBd.de(ex));
        }
        return "redirect:/clientes";
    }
}
