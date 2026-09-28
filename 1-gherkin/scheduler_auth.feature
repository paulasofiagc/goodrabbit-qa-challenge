# language: es
# Reto QA GoodRabbit - Punto 3.a: Diseño de casos de prueba (Gherkin)
# Flujo elegido: Autenticación + Asignación de turnos (Scheduler)

# Actualizado el 25 de septiembre de 2026 tras ejecutar los 5 escenarios contra el ambiente real (https://demo.timekeeper.goodrabbit.tech). Los codigos de respuesta y comportamientos ya no son supuestos: fueron confirmados via Postman.
# Ver evidencia y detalle en README.md y 3-bug-report/.

@scheduler @auth
Característica: Autenticación y asignación de turnos en el Scheduler
  Como administrador de Timekeeper
  Quiero autenticarme y asignar turnos a empleados
  Para planificar la jornada laboral del equipo

  Antecedentes:
    Dado que el API Gateway está disponible en "https://demo.timekeeper.goodrabbit.tech"
    Y existe el empleado con id 1

  # ---------------------------------------------------------------
  # ESCENARIO 1: Camino feliz
  # CONFIRMADO: 200 OK. El backend usa employee_ids como fuente de verdad;
  # shift.employee_id se ignora sin error (ver README, seccion 6).
  # ---------------------------------------------------------------

  @happy_path
  Escenario: Administrador asigna turnos repetidos a un empleado
    Dado que me autentiqué en "/v1/login" con credenciales de administrador válidas
    Y obtuve un access token
    Cuando envío POST a "/v1/schedule/shift/assign" con los siguientes datos:
      | campo        | valor      |
      | employee_ids | [1]        |
      | date         | 2026-09-10 |
      | start_ts     | 13:00:00   |
      | end_ts       | 22:00:00   |
      | duration     | 09:00:00   |
      | timezone     | America/Santiago |
      | repeat       | 2          |
    Entonces la respuesta tiene código 200
    Y el campo "status" es "success"
    Y "data.success" contiene 2 turnos del empleado 1
    Y los turnos corresponden a las fechas "2026-09-10" y "2026-09-11"
    Y al consultar GET "/v1/schedule/shift/schedule" con employee_id__in=1 aparecen ambos turnos

    # Hallazgo adicional confirmado: la respuesta incluye "data.warnings" con
    # rule_code "NO_RULESET_ASSIGNED" cuando el empleado no tiene una regla de
    # horas extra/descansos asignada. El turno se crea igual (no bloquea).

  # ---------------------------------------------------------------
  # ESCENARIO 2: Credenciales inválidas
  # CONFIRMADO: 400 Bad Request.
  # ---------------------------------------------------------------

  @seguridad
  Escenario: Login rechazado con contraseña incorrecta
    Dado que no tengo sesión iniciada
    Cuando envío POST a "/v1/login" con un usuario válido y una contraseña incorrecta
    Entonces la respuesta tiene código 400
    Y la respuesta no contiene el campo "access_token"
    # Hallazgo: la respuesta tarda ~18.6s, incluso mas que un login exitoso (~12s).
    # Ver BUG-002.md.

  # ---------------------------------------------------------------
  # ESCENARIO 3: Falta de permisos / sin token
  # CONFIRMADO: 401 Unauthorized, 221ms (tiempo normal, sin hallazgos de performance).
  # ---------------------------------------------------------------

  @seguridad
  Escenario: Asignar turno sin token de autorización
    Dado que no envío el header "Authorization"
    Cuando envío POST a "/v1/schedule/shift/assign" con un body válido
    Entonces la respuesta tiene código 401
    Y la respuesta indica "Authentication token missing"
    Y no se crea ningún turno para el empleado 1

  # ---------------------------------------------------------------
  # ESCENARIO 4: Datos inválidos (empleado inexistente)
  # CONFIRMADO: 400, con data.total_errors > 0. Ver BUG-003: el mensaje de
  # error expone la URL interna del microservicio de Empleados en el cluster.
  # ---------------------------------------------------------------

  @datos_invalidos
  Escenario: Asignar turno a un empleado inexistente
    Dado que estoy autenticado como administrador
    Cuando envío POST a "/v1/schedule/shift/assign" con employee_ids [999999]
    Entonces la respuesta tiene código 400
    Y "data.total_success" es 0 y "data.total_errors" es mayor a 0
    Y no se crea ningún turno
  

  # ---------------------------------------------------------------
  # ESCENARIO 5: Caso borde (rango horario inconsistente)
  # CONFIRMADO: 400, con un mensaje de validacion claro y especifico
  # ---------------------------------------------------------------
  
  @borde
  Escenario: Asignar turno con hora de término anterior a la de inicio
    Dado que estoy autenticado como administrador
    Cuando envío POST a "/v1/schedule/shift/assign" con start_ts "22:00:00" y end_ts "13:00:00"
    Entonces la respuesta tiene código 400
    Y el mensaje de error es "start_ts must be less than or equal to end_ts"
    Y no se crea ningún turno