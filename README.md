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

> **Nota sobre el ambiente:** la URL entregada inicialmente (`tk-gr.demo.goodrabbit.tech`) no resolvía. Tras reportarlo, se recibió una versión corregida del challenge con la URL correcta (`demo.timekeeper.goodrabbit.tech`). Con el acceso restablecido, se ejecutó la colección completa contra el ambiente real (25 aserciones automatizadas, todas pasando) y se identificaron y documentaron 3 defectos reales (ver `3-bug-report/`).

---

## 2. Estructura del repositorio

```
goodrabbit-qa-challenge/
├── README.md
├── package.json
├── .gitignore
├── 1-gherkin/
│   └── scheduler_auth.feature
├── 2-postman/
│   └── Timekeeper Project (QA) - Tests.postman_collection.json
├── 3-bug-report/
│   ├── BUG-001.md
│   ├── BUG-002.md
│   └── BUG-003.md
├── 4-bonus/
│   └── 
└── evidencias/
    └── 
```

---

## 3. Entregables y estado

| # | Entregable | Peso | Estado |
|---|---|---|---|
| 3.a | Casos de prueba en Gherkin (5 escenarios) | 25% | Completado y validado sintácticamente |
| 3.b | Pruebas de API y aserciones en Postman | 25% | **Completado** — 25 aserciones ejecutadas contra el ambiente real, todas en verde |
| 3.c | Reporte de incidencias | 20% | **Completado** — 3 bugs reales, reproducibles y documentados |
| 4 | Bonus (a elección) | 20% | Pendiente de definir |
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

Se cumple el mínimo pedido (1 camino feliz y 2 o más escenarios de borde, datos inválidos o falta de permisos) y se cubren las tres categorías. Los 5 escenarios fueron ejecutados y verificados contra el ambiente real mediante los requests `[NEG-02]` a `[NEG-05]` de la colección Postman.

**Validación de sintaxis:**

```bash
npm install
npx cucumber-js --dry-run 1-gherkin/scheduler_auth.feature
```

Resultado obtenido: `5 scenarios (5 undefined), 34 steps (34 undefined)`. Sin errores de parseo. Los pasos figuran como *undefined* porque los *step definitions* no se implementaron: el reto pide diseñar los casos, no ejecutarlos vía Cucumber; la ejecución real se hizo en Postman.

### 3.b Pruebas de API (Postman)

Colección: [`2-postman/Timekeeper Project (QA) - Tests.postman_collection.json`](2-postman/) — basada en la entregada con el reto, con correcciones de URL, `client_id`, esquemas de body, tests y los 4 casos negativos.

**Incluye:**
- Login con guardado dinámico del `access_token` y `refresh_token`, y renovación automática antes de que expire (el token dura solo ~10 minutos).
- Aserciones en la pestaña Tests para todos los endpoints: código HTTP, esquema JSON y tiempo de respuesta.
- 4 requests negativos, uno por cada escenario Gherkin (2 al 5).

**Endpoints y resultado de ejecución contra el ambiente real:**

| Endpoint | Tests | Resultado |
|---|---|---|
| `POST /v1/login` | 6 | ✅ 200 OK, pero **~12-18 s de latencia** (BUG-002) |
| `GET /v1/employee/employee` | 4 | ✅ 200 OK, 303 ms |
| `POST /v1/employee/employee/create` | 2 | ✅ 200 OK, 679 ms (tras identificar campos faltantes, BUG-001) |
| `GET /v1/timekeeper/punch_match` | 3 | ✅ 200 OK, 479 ms |
| `POST /v1/mdm_psc/punches/replace_punches` | 3 | ✅ 200 OK, ~10-11 s de latencia (BUG-002) |
| `POST /v1/schedule/shift/assign` | 4 | ✅ 200 OK, turnos creados y confirmados |
| `GET /v1/schedule/shift/schedule` | 3 | ✅ 200 OK, turnos consultados correctamente |
| `[NEG-02]` Login con clave incorrecta | 1 | ✅ 400, pero 18.61 s de latencia (BUG-002) |
| `[NEG-03]` Assign sin token | 1 | ✅ 401, 221 ms |
| `[NEG-04]` Assign a empleado inexistente | 2 | ✅ 400, pero expone URL interna del clúster (BUG-003) |
| `[NEG-05]` Assign con horas invertidas | 2 | ✅ 400, mensaje de validación claro y específico |

**31 aserciones en total, todas en verde.** Validación cruzada adicional: los empleados y turnos creados vía API se verificaron visualmente en el Dashboard Web, confirmando consistencia entre ambos.

### 3.c Reporte de incidencias

| Bug | Tipo | Resumen |
|---|---|---|
| [`BUG-001.md`](3-bug-report/BUG-001.md) | Funcional | `employee/create` requiere `phone_number`, `address` y `pay_period_end`, pero la validación 422 no los declara como obligatorios; sin ellos, falla con un `409` engañoso en vez de un error claro |
| [`BUG-002.md`](3-bug-report/BUG-002.md) | Performance | Latencia de 10 a 18 segundos en operaciones de escritura (`login`, `replace_punches`), tanto en éxito como en fallo |
| [`BUG-003.md`](3-bug-report/BUG-003.md) | Seguridad | El error de "empleado inexistente" expone la URL interna del microservicio de Empleados en el clúster (`*.svc.cluster.local`) |

### 4. Bonus

Pendiente de definir entre k6 (carga y estrés) y scripting de API con Vitest.

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
2. **Credenciales:** `admin` / `contraseña`. No se versionan en este repositorio; se configuran localmente (ver sección 5).
3. **Carga (si se elige k6):** el ambiente es una demo compartida, por lo que se limitará a una carga baja de usuarios virtuales.

---

## 5. Cómo ejecutar

### Requisitos

- Node.js LTS y npm
- Postman
- k6 (solo si se elige el bonus de carga)

### Configuración

1. Importar la colección de `2-postman/` en Postman.
2. En las variables de la colección, completar `username` y `password` con las credenciales entregadas. **No subir credenciales al repositorio.**
3. Verificar que `base_url` sea `https://demo.timekeeper.goodrabbit.tech`.
4. Ejecutar primero `[POST] /v1/login`. El token se guarda automáticamente en `bearer_token` (expira en ~10 minutos; se renueva antes de cada request posterior).
5. Ejecutar los demás requests, o la colección completa desde el Runner.

---

## 6. Observaciones y hallazgos

Confirmados contra el ambiente real:

1. **`client_id` desactualizado en la colección original:** el valor `979e03c4...` no es válido en `demo.timekeeper.goodrabbit.tech`; el correcto es `67d6c2dd...`. Corregido en la colección de `2-postman/`.
2. **Esquema de `employee/create` desactualizado en la colección original:** usa `document_number` (el campo real es `document_employee`) y le faltan 5 campos obligatorios de facto (`pay_rule_id`, `birth_date`, `timezone`, `phone_number`, `address`, `pay_period_end`), de los cuales solo 3 se reportan en el 422 (ver BUG-001).
3. **Estructura de respuesta de `assign` distinta a la documentada:** el ejemplo de la colección muestra `data.success` / `data.errors` como arreglos; la respuesta real usa `data.total_success`, `data.total_errors`, `data.errors` como objeto, y agrega un campo `data.warnings` no documentado.
4. **`shift.employee_id: 0` es ignorado sin advertencia:** el body de `assign` incluye tanto `shift.employee_id` como `employee_ids`; el primero se ignora silenciosamente y prevalece el segundo. No es un bug bloqueante, pero es un campo confuso en el contrato del API.
5. **Warning `NO_RULESET_ASSIGNED`:** al asignar un turno, el sistema advierte que el empleado no tiene una regla ("ruleset") de horas extra/descansos asignada, pero crea el turno igual. No está claro si debería bloquear la creación; queda como pregunta para el equipo de producto.
6. **`disable_ids` con un ID inexistente no genera error:** en `replace_punches`, enviar un ID de marca que no existe no produce ningún error ni advertencia; simplemente no aparece en la respuesta (detalle ampliado en BUG-002).
7. **Punto positivo — validación de horario ejemplar:** `assign` valida correctamente que `start_ts` sea menor o igual a `end_ts`, con un mensaje de error claro y específico (`"start_ts must be less than or equal to end_ts"`), a diferencia de otros endpoints con mensajes genéricos.
8. **3 bugs documentados:** ver sección 3.c y `3-bug-report/`.

---

## 7. Decisiones

- **Priorizar la ejecución real sobre la cantidad de hallazgos simulados:** una vez restablecido el acceso, se optó por confirmar cada hallazgo con múltiples variaciones de datos antes de reportarlo (matriz de 8 intentos en BUG-001), descartando explícitamente hipótesis erróneas en el camino en vez de quedarse con la primera explicación plausible.
- **Validación cruzada API + Dashboard:** los datos creados por API se verificaron visualmente en el Dashboard Web para confirmar consistencia, y la comparación de payloads (API vs. Dashboard, vía DevTools) fue la que permitió aislar la causa raíz real de BUG-001.
- **Un solo flujo Gherkin, en profundidad:** se prefirió cubrir bien un flujo (login, permisos, datos inválidos, borde) antes que abarcar varios de forma superficial.
- **Clasificación de bugs por tipo:** se separaron los hallazgos en funcional, performance y seguridad (BUG-001, 002, 003) en vez de un solo reporte genérico, para reflejar mejor su naturaleza y facilitar la priorización del equipo de desarrollo.
- **Transparencia ante los bloqueos:** se documenta qué se verificó, qué es supuesto y qué quedó pendiente, incluyendo el error inicial de URL en el enunciado y cómo se resolvió.

---

## 8. Próximos pasos

- [ ] Definir y desarrollar el bonus
- [ ] Preparar la presentación (PPT breve, 45 minutos)