# Challenge QA GoodRabbit: Timekeeper

**Postulante:** Paula Gallardo Carrasco
**Cargo:** Analista de Calidad (QA), área R&D
**Entrega:** lunes 28 de septiembre de 2026, antes de las 11:00
**Presentación:** lunes 28 de septiembre de 2026, 15:00 a 15:45

---

## 1. Resumen

Este repositorio contiene el desarrollo del challenge técnico QA de GoodRabbit sobre el Dashboard Web de Timekeeper y sus servicios backend (Autenticación, Empleados, Marcaciones y Scheduler).

**Flujo principal elegido:** Autenticación + Asignación de turnos en el Scheduler.
Se eligió porque cubre en una sola historia el login, los permisos, la validación de datos y la consulta posterior del resultado, y coincide con los endpoints que el reto pide auditar en Postman (`/v1/login`, `/v1/schedule/shift/assign`, `/v1/schedule/shift/schedule`).

> **Nota sobre el ambiente:** la URL entregada inicialmente (`tk-gr.demo.goodrabbit.tech`) no resolvía. Tras reportarlo, se recibió una versión corregida del challenge con la URL correcta (`demo.timekeeper.goodrabbit.tech`). Con el acceso restablecido, se ejecutó la colección completa contra el ambiente real (31+ aserciones automatizadas) y una prueba de carga con k6, identificando y documentando **5 defectos reales** (ver `3-bug-report/`), el más crítico descubierto gracias al bonus de performance.

---

## 2. Estructura del repositorio

```
goodrabbit-qa-challenge/
│
├── README.md
├── package.json
├── .gitignore
│
├── 1-gherkin/
│   └── scheduler_auth.feature
│
├── 2-postman/
│   └── Timekeeper Project (QA) - Tests.postman_collection.json
│
├── 3-bug-report/
│   ├── BUG-001.md
│   ├── BUG-002.md
│   ├── BUG-003.md
│   ├── BUG-004.md
│   └── BUG-005.md
│
├── 4-bonus/
│   └── load-test.js
│
└── evidencias/
    └── (capturas del bloqueo inicial, nslookup y evidencias de los 5 bugs)
```

---

## 3. Entregables y estado

| # | Entregable | Peso | Estado |
|---|---|---|---|
| 3.a | Casos de prueba en Gherkin (5 escenarios) | 25% | **Completado**, validado sintácticamente y confirmado contra el ambiente real |
| 3.b | Pruebas de API y aserciones en Postman | 25% | **Completado** — 31+ aserciones ejecutadas, incluyendo validaciones que permitieron detectar incumplimientos de tiempo de respuesta documentados en BUG-002. |
| 3.c | Reporte de incidencias | 20% | **Completado** — 5 bugs reales, reproducibles y documentados |
| 4 | Bonus: pruebas de carga (k6) | 20% | **Completado** — script en `4-bonus/load-test.js`, halló BUG-004 |
| 5 | Orden y documentación | 10% | Este documento |

### 3.a Casos de prueba (Gherkin)

Archivo: [`1-gherkin/scheduler_auth.feature`](1-gherkin/scheduler_auth.feature)

| # | Escenario | Tipo | Código confirmado contra el ambiente |
|---|---|---|---|
| 1 | Administrador asigna turnos repetidos a un empleado | Camino feliz | 200 OK |
| 2 | Login rechazado con contraseña incorrecta | Seguridad / negativo | 400 |
| 3 | Asignar turno sin token de autorización | Falta de permisos | 401 |
| 4 | Asignar turno a un empleado inexistente | Datos inválidos | 400 (ver BUG-003) |
| 5 | Asignar turno con hora de término anterior a la de inicio | Caso borde | 400 |

Se cumple el mínimo pedido (1 camino feliz y 2 o más escenarios de borde, datos inválidos o falta de permisos) y se cubren las tres categorías. Los 5 escenarios fueron ejecutados y verificados contra el ambiente real mediante los requests correspondientes de la colección Postman.

**Validación de sintaxis:**

```bash
npm install
npx cucumber-js --dry-run 1-gherkin/scheduler_auth.feature
```

Resultado obtenido: `5 scenarios (5 undefined), 34 steps (34 undefined)`. Sin errores de parseo.

### 3.b Pruebas de API (Postman)

Colección: [`2-postman/Timekeeper Project (QA) - Tests.postman_collection.json`](2-postman/) — basada en la entregada con el reto, con correcciones de URL, `client_id`, esquemas de body, tests y los 4 casos negativos.

**Incluye:**
- - Login con guardado dinámico del `access_token` y `refresh_token`. El `access_token` queda disponible automáticamente en la variable de colección `bearer_token` para las solicitudes autenticadas.
- Aserciones en la pestaña Tests para todos los endpoints: código HTTP, esquema JSON y tiempo de respuesta.
- 4 requests negativos, uno por cada escenario Gherkin (2 al 5), más un negativo adicional para `GET /v1/schedule/shift/schedule` sin autenticación.

**Endpoints y resultado de ejecución contra el ambiente real:**

| Endpoint | Resultado |
|---|---|
| `POST /v1/login` | ✅ 200 OK, pero **~12-18 s de latencia sin carga** (BUG-002), y **colapsa bajo carga concurrente** (BUG-004) |
| `GET /v1/employee/employee` | ✅ 200 OK, 303 ms |
| `POST /v1/employee/employee/create` | ✅ 200 OK, 679 ms (tras identificar campos faltantes, BUG-001) |
| `GET /v1/timekeeper/punch_match` | ✅ 200 OK, 479 ms |
| `POST /v1/mdm_psc/punches/replace_punches` | ✅ 200 OK, ~10-11 s de latencia (BUG-002) |
| `POST /v1/schedule/shift/assign` | ✅ 200 OK, turnos creados y confirmados |
| `GET /v1/schedule/shift/schedule` | ✅ 200 OK, turnos consultados correctamente |
| `[NEG-02]` Login con clave incorrecta | ✅ 400, pero 18.61 s de latencia (BUG-002) |
| `[NEG-03]` Assign sin token | ✅ 401, 221 ms |
| `[NEG-04]` Assign a empleado inexistente | ✅ 400, pero expone URL interna del clúster (BUG-003) |
| `[NEG-05]` Assign con horas invertidas | ✅ 400, mensaje de validación claro y específico |

Validación cruzada adicional: los empleados y turnos creados vía API se verificaron visualmente en el Dashboard Web, confirmando consistencia entre ambos.

### 3.c Reporte de incidencias

| Bug | Severidad | Tipo | Resumen |
|---|---|---|---|
| [`BUG-001.md`](3-bug-report/BUG-001.md) | Alta | Funcional | `employee/create` requiere `phone_number`, `address` y `pay_period_end`, pero la validación 422 no los declara como obligatorios; sin ellos, falla con un `409` engañoso en vez de un error claro |
| [`BUG-002.md`](3-bug-report/BUG-002.md) | Media-Alta | Performance | Latencia de 10 a 18 segundos en operaciones de escritura (`login`, `replace_punches`), tanto en éxito como en fallo |
| [`BUG-003.md`](3-bug-report/BUG-003.md) | Media | Seguridad | El error de "empleado inexistente" expone la URL interna del microservicio de Empleados en el clúster (`*.svc.cluster.local`) |
| [`BUG-004.md`](3-bug-report/BUG-004.md) | **Crítica** | Disponibilidad | El backend de autenticación colapsa (503/504) con solo 5 usuarios concurrentes; hallado con el bonus de k6 |
| [`BUG-005.md`](3-bug-report/BUG-005.md) | Alta | Funcional | Los turnos asignados se muestran con un desfase de hasta 3 horas en el Dashboard, por una contradicción entre `shift.start_ts` y `segments[].start_ts` (UTC) |

BUG-004 es el hallazgo de mayor impacto del challenge: confirma bajo carga real la sospecha que dejó abierta BUG-002, y revela una falla de disponibilidad crítica que afectaría a cualquier grupo pequeño de usuarios iniciando sesión al mismo tiempo.

### 4. Bonus: pruebas de carga con k6

Script: [`4-bonus/load-test.js`](4-bonus/load-test.js)

Se eligió **k6** por su conexión directa con los hallazgos de performance ya identificados en pruebas individuales (BUG-002): la hipótesis a validar era si esa latencia empeoraba bajo concurrencia.

**Diseño de la prueba:**
- Dos escenarios: carga sobre `POST /v1/login` y sobre `POST /v1/mdm_psc/punches/replace_punches` (con su propio login previo por usuario virtual).
- Carga baja e incremental (hasta 5 usuarios virtuales), elegida deliberadamente: el ambiente es una demo compartida con otros postulantes, no un servidor de pruebas dedicado, y ya se sabía que el sistema era lento incluso con una sola solicitud.
- Métricas custom por endpoint (duración, tasa de error, conteo de éxitos) además de las métricas estándar de k6.

**Resultado:** con apenas 5 usuarios virtuales concurrentes, el login falló en el 54.54% de los intentos con errores `503`/`504` del API Gateway, y los intentos exitosos tardaron entre 13.75 y 30.19 segundos — peor que el peor caso medido sin concurrencia. Ver el detalle completo, incluyendo los mensajes de error reales del Gateway, en [`BUG-004.md`](3-bug-report/BUG-004.md).

**Cómo ejecutar:**
```powershell
$env:BASE_URL="https://demo.timekeeper.goodrabbit.tech"
$env:QA_USER="admin"
$env:QA_PASS="<contraseña>"
k6 run 4-bonus/load-test.js
```

---

## 4. Supuestos y bloqueos

### Bloqueo inicial: URL del ambiente incorrecta (resuelto)

Al iniciar el challenge, la URL entregada `https://tk-gr.demo.goodrabbit.tech/` no resolvía. Se verificó desde varias vías para descartar un problema local:

| Vía de verificación | Resultado |
|---|---|
| Google Chrome | `DNS_PROBE_FINISHED_NXDOMAIN` |
| `nslookup tk-gr.demo.goodrabbit.tech 8.8.8.8` (DNS de Google) | `Non-existent domain` |
| `nslookup tk-gr.demo.goodrabbit.tech 1.1.1.1` (DNS de Cloudflare) | `Non-existent domain` |
| Postman, Cloud Agent | `Couldn't resolve host` |
| Postman, Desktop Agent | `getaddrinfo ENOTFOUND tk-gr.demo.goodrabbit.tech` |
| `nslookup goodrabbit.tech` / `demo.goodrabbit.tech` | Ambos resuelven |

El bloqueo fue reportado a la reclutadora el 23 de septiembre de 2026. Capturas y salida de `nslookup` en la carpeta `evidencias/`.

**Actualización (24 de septiembre de 2026):** se recibió una versión corregida del challenge (v1.3) con la URL correcta, `https://demo.timekeeper.goodrabbit.tech/`, y la advertencia explícita de que la colección Postman podía traer variables de otro ambiente. Se confirmó en la práctica: el `client_id` del login (`979e03c4...`) no era válido en este ambiente; el correcto (`67d6c2dd...`) se obtuvo inspeccionando el request real del dashboard vía DevTools. Con esta corrección, el login funciona correctamente y se ejecutó la colección completa contra el ambiente real (ver sección 3.b).

### Supuestos adoptados

1. **Datos de prueba:** el empleado de ejemplo de la colección original era `employee_id: 8`, pero el ambiente real solo tenía precargado `employee_id: 1` ("Prueba 260922"). Se usó `1` para los flujos normales y un ID inexistente (`999999`) para el negativo de "empleado no encontrado".
2. **Credenciales:** `admin` / `contraseña` (literalmente el placeholder del PDF). No se versionan en este repositorio; se configuran localmente (ver sección 5) y como variables de entorno para el script de k6.
3. **Carga del bonus:** deliberadamente baja (5 usuarios virtuales), ya que el ambiente es una demo compartida. Aun con esta carga conservadora se identificó una falla crítica (BUG-004).

---

## 5. Cómo ejecutar

### Requisitos

- Node.js LTS y npm
- Postman
- k6

### Configuración de Postman

1. Importar la colección de `2-postman/` en Postman.
2. En las variables de la colección, completar `username` y `password` con las credenciales entregadas. **No subir credenciales al repositorio.**
3. Verificar que `base_url` sea `https://demo.timekeeper.goodrabbit.tech`.
4. Ejecutar primero `[POST] /v1/login`. El token se guarda automáticamente en `bearer_token` y queda disponible para los requests autenticados.
5. Ejecutar los demás requests, o la colección completa desde el Runner.

### Configuración de k6

Ver sección 4 (Bonus) arriba.

---

## 6. Observaciones y hallazgos

Confirmados contra el ambiente real:

1. **`client_id` desactualizado en la colección original:** el valor `979e03c4...` no es válido en `demo.timekeeper.goodrabbit.tech`; el correcto es `67d6c2dd...`. Corregido en la colección de `2-postman/`.
2. **Esquema de `employee/create` desactualizado en la colección original:** usa `document_number` (el campo real es `document_employee`) y le faltan 6 campos obligatorios de facto (`pay_rule_id`, `birth_date`, `timezone`, `phone_number`, `address`, `pay_period_end`), de los cuales solo 3 se reportan en el 422 (ver BUG-001).
3. **Estructura de respuesta de `assign` distinta a la documentada:** el ejemplo de la colección muestra `data.success` / `data.errors` como arreglos; la respuesta real usa `data.total_success`, `data.total_errors`, `data.errors` como objeto, y agrega un campo `data.warnings` no documentado.
4. **`shift.employee_id: 0` es ignorado sin advertencia:** el body de `assign` incluye tanto `shift.employee_id` como `employee_ids`; el primero se ignora silenciosamente y prevalece el segundo.
5. **Warning `NO_RULESET_ASSIGNED`:** al asignar un turno, el sistema advierte que el empleado no tiene una regla de horas extra/descansos asignada, pero crea el turno igual. Queda como pregunta para el equipo de producto.
6. **`disable_ids` con un ID inexistente no genera error:** en `replace_punches`, enviar un ID de marca que no existe no produce ningún error ni advertencia (detalle ampliado en BUG-002).
7. **Punto positivo — validación de horario ejemplar:** `assign` valida correctamente que `start_ts` sea menor o igual a `end_ts`, con un mensaje de error claro y específico, a diferencia de otros endpoints con mensajes genéricos.
8. **5 bugs documentados**, incluyendo una falla crítica de disponibilidad bajo carga (ver sección 3.c y `3-bug-report/`).

---

## 7. Decisiones

- **Priorizar la ejecución real sobre la cantidad de hallazgos simulados:** cada hallazgo se confirmó con múltiples variaciones de datos antes de reportarlo (matriz de 8 intentos en BUG-001), descartando explícitamente hipótesis erróneas en el camino.
- **Validación cruzada API + Dashboard:** los datos creados por API se verificaron visualmente en el Dashboard Web, y la comparación de payloads (API vs. Dashboard, vía DevTools) fue la que permitió aislar la causa raíz real de BUG-001.
- **El bonus como extensión de un hallazgo, no como ejercicio aislado:** en vez de elegir k6 de forma genérica, se usó específicamente para validar bajo carga una sospecha que ya existía (BUG-002), lo que permitió descubrir un problema de mayor severidad (BUG-004) en vez de solo confirmar el original.
- **Clasificación de bugs por tipo:** funcional, performance, seguridad y disponibilidad, para reflejar mejor su naturaleza y facilitar la priorización del equipo de desarrollo.
- **Transparencia ante los bloqueos:** se documenta qué se verificó, qué es supuesto y qué quedó pendiente, incluyendo el error inicial de URL en el enunciado y cómo se resolvió.

---

## 8. Próximos pasos

- [ ] Preparar la presentación (PPT breve, 45 minutos), con foco en la narrativa BUG-002 → BUG-004