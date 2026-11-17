package com.farmacia.seguridad;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.ProviderManager;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

/**
 * PRIMERA barrera de seguridad: qué ROL puede entrar a qué URL.
 * (La SEGUNDA está en DespachadorProcedimientos: qué rol puede ejecutar cada procedimiento.
 *  La TERCERA está en Oracle: los triggers validan las reglas sin importar quién inserte.)
 *
 * Regla de lectura: GET = consultar, POST = modificar. Las reglas se evalúan EN ORDEN:
 * la primera que coincide gana, por eso van de lo más específico a lo más general.
 */
@Configuration
public class SeguridadConfig {

    private static final String[] TODOS = {"ADMIN", "GERENCIA", "ADMIN_SUCURSAL", "REGENTE", "VENDEDOR", "AUDITOR"};
    private static final String[] VENDEN = {"ADMIN", "REGENTE", "VENDEDOR"};
    private static final String[] LEEN_TODO = {"ADMIN", "GERENCIA", "ADMIN_SUCURSAL", "AUDITOR"};
    private static final String[] INVENTARIO = {"ADMIN", "ADMIN_SUCURSAL", "REGENTE"};

    @Bean
    public SecurityFilterChain filtro(HttpSecurity http, AutenticacionFarmacia autenticacion) throws Exception {
        http
            .authenticationManager(new ProviderManager(autenticacion))
            .authorizeHttpRequests(a -> a
                // Recursos públicos: estilos, íconos y archivos de la PWA
                .requestMatchers("/css/**", "/js/**", "/icons/**", "/manifest.webmanifest", "/sw.js",
                                 "/offline.html", "/login", "/salud").permitAll()
                .requestMatchers("/", "/acceso-denegado", "/error").authenticated()

                // ---- Ventas ----
                .requestMatchers(HttpMethod.GET, "/ventas/nuevo").hasAnyRole(VENDEN)
                .requestMatchers(HttpMethod.POST, "/ventas/guardar").hasAnyRole(VENDEN)
                .requestMatchers(HttpMethod.POST, "/ventas/*/anular").hasRole("ADMIN")
                .requestMatchers(HttpMethod.GET, "/ventas", "/ventas/*").hasAnyRole(LEEN_TODO)

                // ---- Clientes: quien vende puede darlos de alta ----
                .requestMatchers(HttpMethod.GET, "/clientes/nuevo").hasAnyRole("ADMIN", "ADMIN_SUCURSAL", "REGENTE", "VENDEDOR")
                .requestMatchers(HttpMethod.POST, "/clientes/guardar").hasAnyRole("ADMIN", "ADMIN_SUCURSAL", "REGENTE", "VENDEDOR")
                .requestMatchers(HttpMethod.GET, "/clientes").hasAnyRole(LEEN_TODO)
                .requestMatchers("/clientes/*/editar").hasAnyRole("ADMIN", "ADMIN_SUCURSAL")

                // ---- Inventario ----
                .requestMatchers(HttpMethod.GET, "/medicamentos", "/lotes").hasAnyRole(TODOS)
                .requestMatchers("/lotes/nuevo", "/lotes/guardar", "/lotes/*/editar", "/lotes/*/trasladar").hasAnyRole(INVENTARIO)
                .requestMatchers(HttpMethod.GET, "/proveedores").hasAnyRole(LEEN_TODO)
                .requestMatchers("/proveedores/nuevo", "/proveedores/guardar", "/proveedores/*/editar")
                    .hasAnyRole("ADMIN", "ADMIN_SUCURSAL")

                // ---- Personal ----
                .requestMatchers(HttpMethod.GET, "/empleados").hasAnyRole(LEEN_TODO)
                .requestMatchers("/empleados/nuevo", "/empleados/guardar", "/empleados/*/editar")
                    .hasAnyRole("ADMIN", "ADMIN_SUCURSAL")

                // ---- Sucursales: consultan los roles de gestión; crea/edita/elimina el ADMIN (anyRequest) ----
                .requestMatchers(HttpMethod.GET, "/sucursales").hasAnyRole(LEEN_TODO)

                // ---- Reportes ----
                .requestMatchers("/reportes/**").hasAnyRole("ADMIN", "GERENCIA", "AUDITOR", "ADMIN_SUCURSAL", "REGENTE")

                // Todo lo demás (eliminar, editar medicamentos...) es del administrador
                .anyRequest().hasRole("ADMIN"))
            .formLogin(f -> f.loginPage("/login").defaultSuccessUrl("/", true).permitAll())
            .logout(l -> l.logoutSuccessUrl("/login?salio").permitAll())
            .exceptionHandling(e -> e.accessDeniedPage("/acceso-denegado"));
        return http.build();
    }
}
