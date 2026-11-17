package com.farmacia.escritorio;

import java.io.File;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URI;
import java.nio.file.Path;
import java.util.List;

/**
 * MODO LOCAL: arranca el backend Spring Boot (farmacia.jar) como un proceso hijo y espera a que
 * responda en /salud. Al cerrar la ventana, el proceso se detiene.
 */
public class ServidorLocal {

    public static final String URL = "http://localhost:8080";
    private Process proceso;

    /** true si ya hay un servidor respondiendo (p. ej. lo arrancaste desde NetBeans). */
    public static boolean responde(String base) {
        try {
            HttpURLConnection c = (HttpURLConnection) URI.create(base + "/salud").toURL().openConnection();
            c.setConnectTimeout(800);
            c.setReadTimeout(800);
            return c.getResponseCode() == 200;
        } catch (IOException e) {
            return false;
        }
    }

    public void iniciar(String rutaJar) throws IOException {
        if (responde(URL)) return;
        File jar = new File(rutaJar);
        if (!jar.isFile()) throw new IOException("No encuentro el archivo " + rutaJar);
        // Usa el MISMO Java con el que corre esta app (jpackage trae su propio Java)
        String java = ProcessHandle.current().info().command().orElse("java");
        proceso = new ProcessBuilder(List.of(java, "-jar", jar.getAbsolutePath()))
                .directory(jar.getParentFile())
                .redirectErrorStream(true)
                .redirectOutput(Path.of(System.getProperty("user.home"), ".farmacia", "servidor.log").toFile())
                .start();
    }

    /** Espera hasta 90 s a que Spring Boot termine de arrancar. */
    public boolean esperar() throws InterruptedException {
        for (int i = 0; i < 180; i++) {
            if (responde(URL)) return true;
            if (proceso != null && !proceso.isAlive()) return false;
            Thread.sleep(500);
        }
        return false;
    }

    public void detener() {
        if (proceso != null && proceso.isAlive()) proceso.destroy();
    }
}
