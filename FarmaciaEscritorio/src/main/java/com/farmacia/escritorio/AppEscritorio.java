package com.farmacia.escritorio;

import javafx.application.Application;
import javafx.application.Platform;
import javafx.concurrent.Task;
import javafx.concurrent.Worker;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.image.Image;
import javafx.scene.input.KeyEvent;
import javafx.scene.layout.*;
import javafx.scene.web.WebEngine;
import javafx.scene.web.WebView;
import javafx.stage.FileChooser;
import javafx.stage.Stage;

import java.io.File;
import java.net.CookieHandler;
import java.net.CookieManager;
import java.util.Optional;

/**
 * Ventana de escritorio de la Farmacia (JavaFX).
 *
 *  ┌──────────────────────────────────────────┐
 *  │  JavaFX Stage (ventana nativa)           │
 *  │   └─ WebView (motor WebKit)              │  ← muestra la misma interfaz que el celular
 *  │        └─ http(s)://servidor/            │  ← Spring Boot + Thymeleaf + Oracle
 *  └──────────────────────────────────────────┘
 *
 * Ctrl+R recarga · Ctrl+, abre la configuración · Ctrl+Q sale.
 */
public class AppEscritorio extends Application {

    private final ServidorLocal servidorLocal = new ServidorLocal();
    private Configuracion config;
    private WebEngine motor;
    private Label estado;

    public static void main(String[] args) {
        launch(args);
    }

    @Override
    public void start(Stage ventana) {
        // Mantiene la sesión (cookie JSESSIONID) entre páginas
        if (CookieHandler.getDefault() == null) CookieHandler.setDefault(new CookieManager());

        config = Configuracion.cargar();
        if (!config.existe() && !pedirConfiguracion()) {
            Platform.exit();
            return;
        }

        WebView vista = new WebView();
        motor = vista.getEngine();
        motor.setUserAgent(motor.getUserAgent() + " FarmaciaEscritorio/1.0");
        motor.titleProperty().addListener((o, a, t) -> ventana.setTitle(t == null ? "Farmacia" : t));
        motor.getLoadWorker().stateProperty().addListener((o, a, s) -> {
            if (s == Worker.State.FAILED) mostrarError("No se pudo abrir " + motor.getLocation()
                    + ".\nRevisa que el servidor esté encendido o cambia la configuración (Ctrl+,).");
        });

        estado = new Label("Conectando…");
        ProgressIndicator rueda = new ProgressIndicator();
        VBox carga = new VBox(16, rueda, estado);
        carga.setAlignment(Pos.CENTER);
        StackPane raiz = new StackPane(vista, carga);
        raiz.setStyle("-fx-background-color: #f5f5f7;");

        Scene escena = new Scene(raiz, 1280, 800);
        // addEventFilter: atrapa la tecla ANTES de que el WebView la consuma
        escena.addEventFilter(KeyEvent.KEY_PRESSED, e -> {
            if (e.isShortcutDown()) switch (e.getCode()) {
                case R -> motor.reload();
                case COMMA -> { if (pedirConfiguracion()) conectar(carga); }
                case Q -> Platform.exit();
                default -> { }
            }
        });

        ventana.setTitle("Farmacia");
        ventana.getIcons().add(new Image(getClass().getResourceAsStream("/icono.png")));
        ventana.setMinWidth(380);
        ventana.setScene(escena);
        ventana.show();
        conectar(carga);
    }

    /** Arranca el servidor local si hace falta (en segundo plano) y luego carga la página. */
    private void conectar(VBox carga) {
        carga.setVisible(true);
        Task<String> tarea = new Task<>() {
            @Override
            protected String call() throws Exception {
                if (config.modo() == Configuracion.Modo.LOCAL) {
                    updateMessage("Iniciando el servidor local (Spring Boot)…");
                    servidorLocal.iniciar(config.jar());
                    if (!servidorLocal.esperar())
                        throw new IllegalStateException("El servidor local no arrancó. Mira ~/.farmacia/servidor.log");
                    return ServidorLocal.URL;
                }
                updateMessage("Conectando con " + config.servidor() + "…");
                return config.servidor();
            }
        };
        estado.textProperty().bind(tarea.messageProperty());
        tarea.setOnSucceeded(e -> { carga.setVisible(false); motor.load(tarea.getValue() + "/"); });
        tarea.setOnFailed(e -> { carga.setVisible(false); mostrarError(tarea.getException().getMessage()); });
        Thread hilo = new Thread(tarea, "conexion");
        hilo.setDaemon(true);
        hilo.start();
    }

    /** Diálogo de configuración: NUBE (URL) o LOCAL (archivo farmacia.jar). */
    private boolean pedirConfiguracion() {
        Dialog<ButtonType> d = new Dialog<>();
        d.setTitle("Configurar Farmacia");
        d.setHeaderText("¿Dónde está el servidor de la farmacia?");

        ToggleGroup grupo = new ToggleGroup();
        RadioButton nube = new RadioButton("En internet (la misma dirección que abres en el celular)");
        RadioButton local = new RadioButton("En este PC (inicia farmacia.jar con Oracle local)");
        nube.setToggleGroup(grupo);
        local.setToggleGroup(grupo);
        (config.modo() == Configuracion.Modo.LOCAL ? local : nube).setSelected(true);

        TextField url = new TextField(config.servidor());
        url.setPromptText("https://mifarmacia.duckdns.org");
        TextField jar = new TextField(config.jar());
        jar.setPromptText("C:\\Farmacia\\farmacia.jar");
        Button buscar = new Button("Buscar…");
        buscar.setOnAction(e -> {
            FileChooser fc = new FileChooser();
            fc.getExtensionFilters().add(new FileChooser.ExtensionFilter("Servidor Spring Boot", "*.jar"));
            File f = fc.showOpenDialog(d.getOwner());
            if (f != null) jar.setText(f.getAbsolutePath());
        });
        url.disableProperty().bind(local.selectedProperty());
        jar.disableProperty().bind(nube.selectedProperty());
        buscar.disableProperty().bind(nube.selectedProperty());

        GridPane g = new GridPane();
        g.setHgap(10);
        g.setVgap(10);
        g.setPadding(new Insets(10));
        g.add(nube, 0, 0, 3, 1);
        g.add(new Label("Dirección:"), 0, 1);
        g.add(url, 1, 1, 2, 1);
        g.add(local, 0, 2, 3, 1);
        g.add(new Label("Archivo:"), 0, 3);
        g.add(jar, 1, 3);
        g.add(buscar, 2, 3);
        GridPane.setHgrow(url, Priority.ALWAYS);
        GridPane.setHgrow(jar, Priority.ALWAYS);

        d.getDialogPane().setContent(g);
        d.getDialogPane().getButtonTypes().addAll(ButtonType.OK, ButtonType.CANCEL);
        Optional<ButtonType> r = d.showAndWait();
        if (r.isEmpty() || r.get() != ButtonType.OK) return false;

        config.modo(local.isSelected() ? Configuracion.Modo.LOCAL : Configuracion.Modo.NUBE);
        config.servidor(url.getText().isBlank() ? "http://localhost:8080" : url.getText());
        config.jar(jar.getText());
        try {
            config.guardar();
        } catch (Exception e) {
            mostrarError("No se pudo guardar la configuración: " + e.getMessage());
        }
        return true;
    }

    private void mostrarError(String mensaje) {
        Alert a = new Alert(Alert.AlertType.ERROR, mensaje, ButtonType.OK);
        a.setHeaderText("Farmacia");
        a.showAndWait();
    }

    @Override
    public void stop() {
        servidorLocal.detener();
    }
}
