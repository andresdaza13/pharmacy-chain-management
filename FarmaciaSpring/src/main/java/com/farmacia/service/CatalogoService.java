package com.farmacia.service;

import lombok.RequiredArgsConstructor;
import com.farmacia.model.MedicamentoVenta;
import com.farmacia.model.Opcion;
import com.farmacia.repository.CatalogoRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

/** Listas de apoyo para los desplegables. Los controladores solo hablan con servicios. */
@RequiredArgsConstructor
@Service
public class CatalogoService {

    private final CatalogoRepository repositorio;


    public List<Opcion> sucursales() { return repositorio.sucursales(); }
    public List<Opcion> proveedores() { return repositorio.proveedores(); }
    public List<Opcion> medicamentos() { return repositorio.medicamentos(); }
    public List<Opcion> empleados() { return repositorio.empleados(); }
    public List<Opcion> empleadosConSucursal() { return repositorio.empleadosConSucursal(); }
    public List<Opcion> clientes() { return repositorio.clientes(); }
    public List<MedicamentoVenta> medicamentosParaVenta(Integer idSucursal) { return repositorio.medicamentosParaVenta(idSucursal); }
    public Optional<String> etiquetaEmpleado(int idEmpleado) { return repositorio.etiquetaEmpleado(idEmpleado); }
    public List<String> metodosPago() { return repositorio.metodosPago(); }
    public List<String> cargos() { return repositorio.cargos(); }
}
