La guía completa está en ../README.md (arquitectura, cómo ejecutar, despliegue y app de escritorio).

Orden de scripts en Oracle (conexión farmacia, XEPDB1, Run Script F5):
  00..02  tus scripts de tablas y datos
  03_paquetes.sql          paquetes CRUD + secuencias
  04_roles.sql             roles y usuarios de ejemplo
  05_usuario_empleado.sql  liga usuario de Oracle <-> empleado
  06_logica_negocio.sql    funciones, pkg_farmacia, TRIGGERS y vistas de reportes  <- NUEVO
