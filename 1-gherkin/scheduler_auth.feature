# language: es
# Reto QA GoodRabbit - Punto 3.a: Diseño de casos de prueba (Gherkin)
# Flujo elegido: Autenticación + Asignación de turnos (Scheduler)
#
# NOTA DE SUPUESTOS:
# Los escenarios se diseñaron a partir del PDF del reto y de la colección Postman
# (ejemplos de request/response). Los códigos HTTP de error marcados con "SUPUESTO"
# siguen la convención REST y deben validarse contra el ambiente QA.

@scheduler @auth
Característica: Autenticación y asignación de turnos en el Scheduler
  Como administrador de Timekeeper
  Quiero autenticarme y asignar turnos a empleados
  Para planificar la jornada laboral del equipo

  Antecedentes:
    Dado que el API Gateway está disponible en "https://tk-gr.demo.goodrabbit.tech"
    Y existe el empleado con id 8

  # ---------------------------------------------------------------
  # ESCENARIO 1: Camino feliz
  # ---------------------------------------------------------------
  @happy_path
  Escenario: Administrador asigna turnos repetidos a un empleado
    Dado que me autentiqué en "/v1/login" con credenciales de administrador válidas
    Y obtuve un access token
    Cuando envío POST a "/v1/schedule/shift/assign" con los siguientes datos:
      | campo        | valor      |
      | employee_ids | [8]        |
      | date         | 2026-09-01 |
      | start_ts     | 13:00:00   |
      | end_ts       | 22:00:00   |
      | duration     | 09:00:00   |
      | timezone     | America/Santiago |
      | repeat       | 2          |
    Entonces la respuesta tiene código 200
    Y el campo "status" es "success"
    Y "data.success" contiene 2 turnos del empleado 8 con fechas "2026-09-01" y "2026-09-02"
    Y "data.errors" está vacío
    Y al consultar GET "/v1/schedule/shift/schedule" con employee_id__in=8 aparecen ambos turnos con sus segmentos

  # ---------------------------------------------------------------
  # ESCENARIO 2: Credenciales inválidas
  # ---------------------------------------------------------------
  @seguridad @negativo
  Escenario: Login rechazado con contraseña incorrecta
    Dado que no tengo sesión iniciada
    Cuando envío POST a "/v1/login" con un usuario válido y una contraseña incorrecta
    # SUPUESTO: el API responde 400 o 401 ante credenciales inválidas
    Entonces la respuesta tiene código 400 o 401
    Y la respuesta no contiene el campo "access_token"

  # ---------------------------------------------------------------
  # ESCENARIO 3: Falta de permisos / sin token
  # ---------------------------------------------------------------
  @seguridad @negativo
  Escenario: Asignar turno sin token de autorización
    Dado que no envío el header "Authorization"
    Cuando envío POST a "/v1/schedule/shift/assign" con un body válido
    # SUPUESTO: el API responde 401 ante ausencia de token
    Entonces la respuesta tiene código 401
    Y no se crea ningún turno para el empleado 8

  # ---------------------------------------------------------------
  # ESCENARIO 4: Datos inválidos (empleado inexistente)
  # ---------------------------------------------------------------
  @datos_invalidos @negativo
  Escenario: Asignar turno a un empleado inexistente
    Dado que estoy autenticado como administrador
    Cuando envío POST a "/v1/schedule/shift/assign" con employee_ids [999999]
    # SUPUESTO: el API responde 400, 404 o 422, o informa el error dentro de "data.errors"
    Entonces no se crea ningún turno
    Y la respuesta indica que el empleado no existe

  # ---------------------------------------------------------------
  # ESCENARIO 5: Caso borde (rango horario inconsistente)
  # ---------------------------------------------------------------
  @borde @negativo
  Escenario: Asignar turno con hora de término anterior a la de inicio
    Dado que estoy autenticado como administrador
    Cuando envío POST a "/v1/schedule/shift/assign" con start_ts "22:00:00" y end_ts "13:00:00"
    # SUPUESTO: el API rechaza la solicitud con un error de validación (400 o 422)
    Entonces el sistema rechaza la solicitud con un error de validación
    Y no se crea ningún turno
