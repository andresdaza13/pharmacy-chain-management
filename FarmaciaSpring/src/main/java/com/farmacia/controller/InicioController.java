package com.farmacia.controller;

import com.farmacia.despacho.Rol;
import com.farmacia.exception.MensajesBd;
import com.farmacia.repository.ReporteRepository;
import com.farmacia.seguridad.UsuarioFarmacia;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataAccessException;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

@Controller
@RequiredArgsConstructor
public class InicioController {

    private final ReporteRepository reportes;

    /** Panel de inicio con tarjetas. El vendedor va directo a registrar una venta. */
    @GetMapping("/")
    public String inicio(@AuthenticationPrincipal UsuarioFarmacia usuario, Model model) {
        boolean soloVende = usuario.tiene(Rol.VENDEDOR) && !usuario.tiene(Rol.ADMIN)
                && !usuario.tiene(Rol.REGENTE) && !usuario.tiene(Rol.GERENCIA);
        if (soloVende) return "redirect:/ventas/nuevo";
        model.addAttribute("hoy", LocalDate.now().format(
                DateTimeFormatter.ofPattern("EEEE d 'de' MMMM", Locale.forLanguageTag("es-CO"))));
        try {
            model.addAttribute("resumen", reportes.resumen());
        } catch (DataAccessException ex) {
            model.addAttribute("error", MensajesBd.de(ex));
        }
        return "inicio";
    }

    /** Usado por Docker/la app de escritorio para saber si el servidor ya arrancó. */
    @GetMapping("/salud")
    @ResponseBody
    public ResponseEntity<String> salud() {
        return ResponseEntity.ok("ok");
    }
}
