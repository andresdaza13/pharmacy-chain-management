package com.farmacia.seguridad;

import com.farmacia.despacho.Rol;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.*;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Properties;
import java.util.Set;

/**
 * Inicio de sesión con USUARIOS DE ORACLE (único mecanismo de acceso; los clientes no inician sesión).
 * Se abre una conexión real con el usuario y la clave escritos. Si Oracle la acepta, el rol de la
 * aplicación se deduce de los roles de Oracle del usuario:
 *     DBA o admin_farmacia -> ADMIN | gerencia -> GERENCIA | administrador_sucursal -> ADMIN_SUCURSAL
 *     regente -> REGENTE | vendedor -> VENDEDOR | auditor -> AUDITOR
 * Luego se busca a qué empleado está ligado el usuario (tabla usuario_empleado).
 */
@Component
public class AutenticacionFarmacia implements AuthenticationProvider {

    private static final String MSG_INVALIDO = "Usuario o contraseña incorrectos.";

    private final JdbcTemplate jdbc;
    private final String urlOracle;

    public AutenticacionFarmacia(JdbcTemplate jdbc, @Value("${spring.datasource.url}") String urlOracle) {
        this.jdbc = jdbc;
        this.urlOracle = urlOracle;
    }

    @Override
    public Authentication authenticate(Authentication auth) throws AuthenticationException {
        String usuario = auth.getName() == null ? "" : auth.getName().trim();
        String clave = auth.getCredentials() == null ? "" : auth.getCredentials().toString();
        if (usuario.isEmpty() || clave.isEmpty()) {
            throw new BadCredentialsException(MSG_INVALIDO);
        }

        List<GrantedAuthority> roles = rolesDesdeOracle(usuario, clave);
        Integer idEmpleado = buscarEmpleado(usuario);
        Integer idSucursal = idEmpleado == null ? null : buscarSucursal(idEmpleado);

        UsuarioFarmacia principal = new UsuarioFarmacia(usuario, roles, idEmpleado, idSucursal);
        return UsernamePasswordAuthenticationToken.authenticated(principal, null, roles);
    }

    @Override
    public boolean supports(Class<?> tipo) {
        return UsernamePasswordAuthenticationToken.class.isAssignableFrom(tipo);
    }

    private List<GrantedAuthority> rolesDesdeOracle(String usuario, String clave) {
        Properties props = new Properties();
        props.setProperty("user", usuario);
        props.setProperty("password", clave);
        props.setProperty("oracle.net.CONNECT_TIMEOUT", "5000");

        Set<String> rolesOracle = new HashSet<>();
        try (Connection c = DriverManager.getConnection(urlOracle, props);
             Statement st = c.createStatement();
             ResultSet rs = st.executeQuery("SELECT role FROM session_roles")) {
            while (rs.next()) rolesOracle.add(rs.getString(1).toUpperCase());
        } catch (SQLException ex) {
            throw traducir(ex);
        }

        // Rol de Oracle -> rol de la aplicación. Un usuario puede tener varios.
        List<GrantedAuthority> autoridades = new ArrayList<>();
        if (tieneAlguno(rolesOracle, "DBA", "ADMIN_FARMACIA")) agregar(autoridades, Rol.ADMIN);
        if (tieneAlguno(rolesOracle, "GERENCIA")) agregar(autoridades, Rol.GERENCIA);
        if (tieneAlguno(rolesOracle, "ADMINISTRADOR_SUCURSAL")) agregar(autoridades, Rol.ADMIN_SUCURSAL);
        if (tieneAlguno(rolesOracle, "REGENTE")) agregar(autoridades, Rol.REGENTE);
        if (tieneAlguno(rolesOracle, "VENDEDOR")) agregar(autoridades, Rol.VENDEDOR);
        if (tieneAlguno(rolesOracle, "AUDITOR")) agregar(autoridades, Rol.AUDITOR);

        if (autoridades.isEmpty()) {
            throw new InsufficientAuthenticationException(
                    "Oracle aceptó tus datos, pero tu usuario no tiene un rol de la aplicación "
                    + "(admin_farmacia, gerencia, administrador_sucursal, regente, vendedor o auditor).");
        }
        return autoridades;
    }

    /** Empleado ligado a este usuario de Oracle; null si no hay vínculo (o la tabla aún no existe). */
    private Integer buscarEmpleado(String usuario) {
        try {
            List<Integer> ids = jdbc.queryForList(
                    "SELECT id_empleado FROM usuario_empleado WHERE username = UPPER(?)", Integer.class, usuario);
            return ids.isEmpty() ? null : ids.get(0);
        } catch (DataAccessException ex) {
            return null;
        }
    }

    private Integer buscarSucursal(int idEmpleado) {
        try {
            List<Integer> ids = jdbc.queryForList(
                    "SELECT id_sucursal FROM Empleado WHERE id_empleado = ?", Integer.class, idEmpleado);
            return ids.isEmpty() ? null : ids.get(0);
        } catch (DataAccessException ex) {
            return null;
        }
    }

    private static void agregar(List<GrantedAuthority> lista, Rol rol) {
        lista.add(new SimpleGrantedAuthority(rol.autoridad()));
    }

    private static boolean tieneAlguno(Set<String> roles, String... nombres) {
        for (String n : nombres) if (roles.contains(n)) return true;
        return false;
    }

    private AuthenticationException traducir(SQLException ex) {
        return switch (ex.getErrorCode()) {
            case 1017 -> new BadCredentialsException(MSG_INVALIDO);
            case 28000 -> new LockedException("La cuenta de Oracle está bloqueada.");
            case 28001 -> new CredentialsExpiredException("La contraseña de Oracle expiró.");
            case 1045 -> new InsufficientAuthenticationException("El usuario de Oracle no tiene permiso CREATE SESSION.");
            default -> new AuthenticationServiceException("No se pudo validar con Oracle: "
                    + String.valueOf(ex.getMessage()).lines().findFirst().orElse(""));
        };
    }
}
