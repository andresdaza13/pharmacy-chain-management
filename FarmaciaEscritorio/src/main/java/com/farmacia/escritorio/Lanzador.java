package com.farmacia.escritorio;

/**
 * Punto de entrada del .jar "gordo" (shade).
 * Truco conocido: si la clase principal extiende javafx.application.Application y JavaFX no está
 * en el module-path, Java se niega a arrancar. Una clase intermedia que NO extiende Application lo evita.
 */
public final class Lanzador {
    public static void main(String[] args) {
        AppEscritorio.main(args);
    }
}
