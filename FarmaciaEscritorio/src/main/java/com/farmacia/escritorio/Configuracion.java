package com.farmacia.escritorio;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

/**
 * Preferencias guardadas en  <carpeta de usuario>/.farmacia/escritorio.properties
 *   modo     = NUBE | LOCAL
 *   servidor = URL del servidor en modo NUBE (ej. https://mifarmacia.duckdns.org)
 *   jar      = ruta de farmacia.jar en modo LOCAL
 */
public class Configuracion {

    public enum Modo { NUBE, LOCAL }

    private static final Path ARCHIVO = Path.of(System.getProperty("user.home"), ".farmacia", "escritorio.properties");
    private final Properties p = new Properties();

    public static Configuracion cargar() {
        Configuracion c = new Configuracion();
        if (Files.exists(ARCHIVO)) {
            try (InputStream in = Files.newInputStream(ARCHIVO)) {
                c.p.load(in);
            } catch (IOException ignorada) {
                // si el archivo está dañado se usan los valores por defecto
            }
        }
        return c;
    }

    public void guardar() throws IOException {
        Files.createDirectories(ARCHIVO.getParent());
        try (OutputStream out = Files.newOutputStream(ARCHIVO)) {
            p.store(out, "Configuracion de Farmacia (escritorio)");
        }
    }

    public boolean existe() { return Files.exists(ARCHIVO); }

    public Modo modo() {
        try { return Modo.valueOf(p.getProperty("modo", "NUBE")); } catch (IllegalArgumentException e) { return Modo.NUBE; }
    }
    public void modo(Modo m) { p.setProperty("modo", m.name()); }

    public String servidor() { return p.getProperty("servidor", "http://localhost:8080"); }
    public void servidor(String url) { p.setProperty("servidor", url.trim().replaceAll("/+$", "")); }

    public String jar() { return p.getProperty("jar", ""); }
    public void jar(String ruta) { p.setProperty("jar", ruta.trim()); }
}
