package com.farmacia.controller;

import lombok.RequiredArgsConstructor;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.MedicamentoForm;
import com.farmacia.service.MedicamentoService;
import jakarta.validation.Valid;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/** CONTROLADOR (MVC): recibe las peticiones HTTP, llama al servicio y elige la vista. */
@RequiredArgsConstructor
@Controller
@RequestMapping("/medicamentos")
public class MedicamentoController {

    private final MedicamentoService servicio;


    @GetMapping
    public String listar(@RequestParam(name = "q", defaultValue = "") String q, Model model) {
        model.addAttribute("medicamentos", servicio.listar(q));
        model.addAttribute("q", q);
        return "medicamentos/lista";
    }

    @GetMapping("/nuevo")
    public String nuevo(Model model) {
        model.addAttribute("form", new MedicamentoForm());
        model.addAttribute("categorias", servicio.categorias());
        return "medicamentos/form";
    }

    @GetMapping("/{id}/editar")
    public String editar(@PathVariable int id, Model model, RedirectAttributes ra) {
        try {
            model.addAttribute("form", MedicamentoForm.desde(servicio.obtener(id)));
            model.addAttribute("categorias", servicio.categorias());
            return "medicamentos/form";
        } catch (ReglaNegocioException ex) {
            ra.addFlashAttribute("error", ex.getMessage());
            return "redirect:/medicamentos";
        }
    }

    @PostMapping("/guardar")
    public String guardar(@Valid @ModelAttribute("form") MedicamentoForm form,
                          BindingResult resultado, Model model, RedirectAttributes ra) {
        if (resultado.hasErrors()) {
            model.addAttribute("categorias", servicio.categorias());
            return "medicamentos/form";
        }
        try {
            boolean esNuevo = form.getId() == null;
            servicio.guardar(form);
            ra.addFlashAttribute("ok", esNuevo ? "Medicamento creado correctamente."
                                               : "Medicamento actualizado correctamente.");
            return "redirect:/medicamentos";
        } catch (DataAccessException | ReglaNegocioException ex) {
            model.addAttribute("error", mensaje(ex));
            model.addAttribute("categorias", servicio.categorias());
            return "medicamentos/form";
        }
    }

    @PostMapping("/{id}/eliminar")
    public String eliminar(@PathVariable int id, RedirectAttributes ra) {
        try {
            servicio.eliminar(id);
            ra.addFlashAttribute("ok", "Medicamento eliminado.");
        } catch (DataAccessException | ReglaNegocioException ex) {
            ra.addFlashAttribute("error", mensaje(ex));
        }
        return "redirect:/medicamentos";
    }

    private String mensaje(RuntimeException ex) {
        return (ex instanceof DataAccessException dae) ? dae.getMostSpecificCause().getMessage()
                                                       : ex.getMessage();
    }
}
