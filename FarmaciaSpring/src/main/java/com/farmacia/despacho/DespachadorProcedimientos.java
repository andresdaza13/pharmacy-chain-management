package com.farmacia.despacho;

import com.farmacia.exception.ReglaNegocioException;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.sql.CallableStatement;
import java.sql.SQLException;
import java.sql.Types;
import java.time.LocalDate;
import java.util.Arrays;

/**
 * DESPACHADOR: único punto de la aplicación que ejecuta procedimientos de Oracle.
 *   1. Verifica que la operación esté en el catálogo (whitelist) -> evita inyección SQL.
 *   2. Verifica que el usuario autenticado tenga un rol permitido.
 *   3. Valida la cantidad de parámetros.
 *   4. Arma y ejecuta la llamada PL/SQL:  {call paquete.procedimiento(?, ?, ..., ?)}
 */
@Component
@RequiredArgsConstructor
public class DespachadorProcedimientos {

    private final JdbcTemplate jdbc;

    /** Versión "dinámica": la operación llega como texto, p. ej. "PROVEEDOR_CREAR". */
    public Integer ejecutar(String nombreOperacion, Object... args) {
        Operacion op;
        try {
            op = Operacion.valueOf(nombreOperacion.trim().toUpperCase());
        } catch (IllegalArgumentException | NullPointerException ex) {
            throw new ReglaNegocioException("Operación no permitida: " + nombreOperacion);
        }
        return ejecutar(op, args);
    }

    /** @return el ID generado si la operación tiene parámetro OUT; null en los demás casos. */
    public Integer ejecutar(Operacion op, Object... args) {
        verificarPermiso(op);
        if (args.length != op.entradas()) {
            throw new IllegalArgumentException(op + " espera " + op.entradas()
                    + " parámetros y recibió " + args.length);
        }
        int total = args.length + (op.conSalida() ? 1 : 0);
        String marcas = String.join(",", java.util.Collections.nCopies(total, "?"));

        return jdbc.execute("{call " + op.llamada() + "(" + marcas + ")}", (CallableStatement cs) -> {
            int i = 1;
            for (Object o : args) asignar(cs, i++, o);
            if (op.conSalida()) cs.registerOutParameter(i, Types.NUMERIC);
            cs.execute();
            return op.conSalida() ? cs.getInt(i) : null;
        });
    }

    private void verificarPermiso(Operacion op) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        boolean permitido = auth != null && auth.isAuthenticated()
                && Arrays.stream(op.roles()).anyMatch(r ->
                        auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals(r.autoridad())));
        if (!permitido) {
            throw new AccessDeniedException("Tu rol no tiene permiso para ejecutar " + op);
        }
    }

    /** Convierte cada tipo de Java al tipo que Oracle espera. */
    private static void asignar(CallableStatement cs, int i, Object o) throws SQLException {
        if (o == null) {
            cs.setNull(i, Types.VARCHAR);
        } else if (o instanceof LocalDate d) {
            cs.setDate(i, java.sql.Date.valueOf(d));          // Oracle espera java.sql.Date
        } else {
            cs.setObject(i, o);
        }
    }
}
