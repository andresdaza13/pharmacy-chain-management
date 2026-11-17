package com.farmacia.controller;

import com.farmacia.exception.MensajesBd;
import com.farmacia.repository.ReporteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataAccessException;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/** Estadísticas con gráficas + los cinco reportes del documento, en pestañas (?tab=...). */
@Controller
@RequestMapping("/reportes")
@RequiredArgsConstructor
public class ReporteController {

    private static final Set<String> AGRUPACIONES = Set.of("sucursal", "empleado", "dia");

    private final ReporteRepository reportes;

    @GetMapping
    public String ver(@RequestParam(defaultValue = "estadisticas") String tab,
                      @RequestParam(defaultValue = "sucursal") String por,
                      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
                      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta,
                      Model model) {
        LocalDate fin = hasta != null ? hasta : LocalDate.now();
        LocalDate inicio = desde != null ? desde : fin.minusDays(29);   // por defecto: últimos 30 días
        String agrupacion = AGRUPACIONES.contains(por) ? por : "sucursal";

        model.addAttribute("tab", tab);
        model.addAttribute("por", agrupacion);
        model.addAttribute("desde", inicio);
        model.addAttribute("hasta", fin);
        try {
            switch (tab) {
                case "estadisticas" -> {
                    // Indicadores + datos de las gráficas. Thymeleaf los convierte a JSON para Chart.js.
                    model.addAttribute("kpi", reportes.indicadores(inicio, fin));
                    Map<String, Object> graficas = new LinkedHashMap<>();
                    graficas.put("porDia", reportes.ventasPorDia(inicio, fin));
                    graficas.put("porSucursal", reportes.ventasPorSucursal(inicio, fin));
                    graficas.put("porMetodo", reportes.ventasPorMetodo(inicio, fin));
                    graficas.put("topMedicamentos", reportes.topMedicamentos(inicio, fin));
                    graficas.put("lotesPorEstado", reportes.lotesPorEstado());
                    model.addAttribute("graficas", graficas);
                    model.addAttribute("filas", java.util.List.of());
                }
                case "mas-vendidos" -> model.addAttribute("filas", reportes.masVendidos(5));
                case "lotes" -> model.addAttribute("filas", reportes.lotesAlerta());
                case "receta" -> model.addAttribute("filas", reportes.ventasReceta());
                case "proveedores" -> model.addAttribute("filas", reportes.lotesPorProveedor());
                default -> {
                    var filas = reportes.ventas(agrupacion, inicio, fin);
                    model.addAttribute("filas", filas);
                    model.addAttribute("granTotal", filas.stream().map(f -> f.total())
                            .reduce(BigDecimal.ZERO, BigDecimal::add));
                    BigDecimal max = filas.stream().map(f -> f.total()).max(BigDecimal::compareTo).orElse(BigDecimal.ONE);
                    model.addAttribute("maximo", max.signum() == 0 ? BigDecimal.ONE : max);
                }
            }
        } catch (DataAccessException ex) {
            model.addAttribute("error", MensajesBd.de(ex));
            model.addAttribute("filas", java.util.List.of());
        }
        return "reportes/index";
    }
}
