package com.farmacia.exception;

import org.springframework.dao.DataAccessException;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Traduce errores de Oracle (ORA-xxxxx) a mensajes entendibles para el usuario. */
public final class MensajesBd {

    /** Errores propios de RAISE_APPLICATION_ERROR (-20000 a -20999): el texto ya está escrito para el usuario. */
    private static final Pattern PROPIO = Pattern.compile("ORA-20\\d{3}: ([^\\n]+?)(?:\\s*ORA-\\d{5}.*)?$", Pattern.MULTILINE);

    private MensajesBd() {}

    public static String de(RuntimeException ex) {
        if (ex instanceof DataAccessException dae) {
            String m = String.valueOf(dae.getMostSpecificCause().getMessage());
            Matcher propio = PROPIO.matcher(m);
            if (propio.find()) return propio.group(1).trim();
            if (m.contains("ORA-00001")) return "Ya existe un registro con ese valor único (documento, NIT, etc.).";
            if (m.contains("ORA-02292")) return "No se puede eliminar: tiene registros asociados (ventas, lotes, etc.).";
            if (m.contains("ORA-02291")) return "Alguno de los datos relacionados no existe.";
            if (m.contains("ORA-02290")) return "Un valor no cumple las reglas de la base de datos. Revisa los datos.";
            if (m.contains("ORA-12899")) return "Un texto es demasiado largo para su campo.";
            if (m.contains("ORA-01400")) return "Falta un dato obligatorio.";
            if (m.contains("ORA-04091")) return "Un disparador consultó la tabla que se está modificando (tabla mutante).";
            if (m.contains("ORA-06550") || m.contains("PLS-00201"))
                return "Falta un objeto en Oracle. ¿Ejecutaste scripts/06_logica_negocio.sql?";
            return m.lines().findFirst().orElse(m);
        }
        return ex.getMessage();
    }
}
