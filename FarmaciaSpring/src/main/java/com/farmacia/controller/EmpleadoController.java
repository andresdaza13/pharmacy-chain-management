package com.farmacia.controller;

import lombok.RequiredArgsConstructor;
import com.farmacia.exception.MensajesBd;
import com.farmacia.exception.ReglaNegocioException;
import com.farmacia.model.EmpleadoForm;
import com.farmacia.service.EmpleadoService;
import com.farmacia.service.CatalogoService;
import jakarta.validation.Valid;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@RequiredArgsConstructor
@Controller
@RequestMapping("/empleados")
public class EmpleadoController {

    private final EmpleadoService servicio;
    private final CatalogoService catalogo;


    @GetMapping
    public String listar(@RequestParam(name = "q", defaultValue = "") String q, Model model) {
        model.addAttribute("empleados", servicio.listar(q));
        model.addAttribute("q", q);
        return "empleados/lista";
    }

    @GetMapping("/nuevo")
    public String nuevo(Model model) {
        model.addAttribute("form", new EmpleadoForm());
        model.addAttribute("sucursales", catalogo.sucursales());
            model.addAttribute("cargos", catalogo.cargos());
        return "empleados/form";
    }

    @GetMapping("/{id}/editar")
    public String editar(@PathVariable int id, Model model, RedirectAttributes ra) {
        try {
            model.addAttribute("form", EmpleadoForm.desde(servicio.obtener(id)));
            model.addAttribute("sucursales", catalogo.sucursales());
            model.addAttribute("cargos", catalogo.cargos());
            return "empleados/form";
        } catch (ReglaNegocioException ex) {
            ra.addFlashAttribute("error", ex.getMessage());
            return "redirect:/empleados";
        }
    }

    @PostMapping("/guardar")
    public String guardar(@Valid @ModelAttribute("form") EmpleadoForm form,
                          BindingResult resultado, Model model, RedirectAttributes ra) {
        if (resultado.hasErrors()) {
            model.addAttribute("sucursales", catalogo.sucursales());
            model.addAttribute("cargos", catalogo.cargos());
            return "empleados/form";
        }
        try {
            boolean esNuevo = form.getId() == null;
            servicio.guardar(form);
            ra.addFlashAttribute("ok", esNuevo ? "Empleado creado correctamente." : "Empleado actualizado correctamente.");
            return "redirect:/empleados";
        } catch (DataAccessException | ReglaNegocioException ex) {
            model.addAttribute("error", MensajesBd.de(ex));
            model.addAttribute("sucursales", catalogo.sucursales());
            model.addAttribute("cargos", catalogo.cargos());
            return "empleados/form";
        }
    }

    @PostMapping("/{id}/eliminar")
    public String eliminar(@PathVariable int id, RedirectAttributes ra) {
        try {
            servicio.eliminar(id);
            ra.addFlashAttribute("ok", "Empleado eliminado.");
        } catch (DataAccessException | ReglaNegocioException ex) {
            ra.addFlashAttribute("error", MensajesBd.de(ex));
        }
        return "redirect:/empleados";
    }
}
