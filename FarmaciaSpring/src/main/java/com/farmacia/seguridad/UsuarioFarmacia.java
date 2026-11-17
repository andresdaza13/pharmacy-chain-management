package com.farmacia.seguridad;

import com.farmacia.despacho.Rol;
import lombok.Getter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.User;

import java.util.Arrays;
import java.util.Collection;

/**
 * Usuario que inició sesión. Además del nombre y los roles guarda a qué EMPLEADO corresponde
 * (tabla usuario_empleado) y en qué SUCURSAL trabaja. Así la venta y el lote se registran a nombre
 * del empleado correcto (MER: Empleado registra Venta/Lote, pertenece a Sucursal).
 * idEmpleado e idSucursal son null si el usuario no está ligado a un empleado (p. ej. el administrador).
 */
@Getter
public class UsuarioFarmacia extends User {

    private final Integer idEmpleado;
    private final Integer idSucursal;

    public UsuarioFarmacia(String username, Collection<? extends GrantedAuthority> autoridades,
                           Integer idEmpleado, Integer idSucursal) {
        super(username, "", autoridades);
        this.idEmpleado = idEmpleado;
        this.idSucursal = idSucursal;
    }

    public boolean ligadoAEmpleado() { return idEmpleado != null; }

    public boolean tiene(Rol rol) {
        return getAuthorities().stream().anyMatch(a -> a.getAuthority().equals(rol.autoridad()));
    }

    /** Rol más alto, para mostrarlo en el menú. El orden del enum va de más a menos permisos. */
    public String rolVisible() {
        return Arrays.stream(Rol.values()).filter(this::tiene).findFirst().map(Rol::etiqueta).orElse("Usuario");
    }
}
