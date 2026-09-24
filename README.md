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

> **Importante:** el ambiente QA (`tk-gr.demo.goodrabbit.tech`) **no estuvo disponible** durante el desarrollo. Ver la sección 4. Todo lo que dependía de ejecutar contra el ambiente está claramente marcado como pendiente o como supuesto.

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
│   └── (colección con tests y negativos)
├── 3-bug-report/
│   └── BUG-001.md
├── 4-bonus/
│   └── (script del bonus elegido)
└── evidencia/
    └── (capturas del error de acceso y salida de nslookup)
```

---

## 3. Entregables y estado

| # | Entregable | Peso | Estado |
|---|---|---|---|
| 3.a | Casos de prueba en Gherkin (5 escenarios) | 25% | Completado y validado sintácticamente |
| 3.b | Pruebas de API y aserciones en Postman | 25% | En desarrollo (ejecución pendiente de acceso al ambiente) |
| 3.c | Reporte de incidencias | 20% | Pendiente |
| 4 | Bonus (a elección) | 20% | Pendiente de definir |
| 5 | Orden y documentación | 10% | Este documento |

### 3.a Casos de prueba (Gherkin)

Archivo: [`1-gherkin/scheduler_auth.feature`](1-gherkin/scheduler_auth.feature)

| # | Escenario | Tipo |
|---|---|---|
| 1 | Administrador asigna turnos repetidos a un empleado | Camino feliz |
| 2 | Login rechazado con contraseña incorrecta | Seguridad / negativo |
| 3 | Asignar turno sin token de autorización | Falta de permisos |
| 4 | Asignar turno a un empleado inexistente | Datos inválidos |
| 5 | Asignar turno con hora de término anterior a la de inicio | Caso borde |

Se cumple el mínimo pedido (1 camino feliz y 2 o más escenarios de borde, datos inválidos o falta de permisos) y se cubren las tres categorías.

**Validación de sintaxis:**

```bash
npm install
npx cucumber-js --dry-run 1-gherkin/scheduler_auth.feature
```

Resultado obtenido: `5 scenarios (5 undefined), 34 steps (34 undefined)`. Sin errores de parseo. Los pasos figuran como *undefined* porque los *step definitions* no se implementaron: el reto pide diseñar los casos, y sin ambiente disponible su ejecución no habría sido verificable.

### 3.b Pruebas de API (Postman)

Colección de origen: `Timekeeper Project (QA).postman_collection.json`, entregada con el reto.

Alcance previsto:

- Login con guardado dinámico del token (`bearer_token`) y renovación automática antes de cada request.
- Aserciones en la pestaña Tests para los endpoints críticos: código HTTP, esquema JSON y tiempo de respuesta.
- Carpeta de casos negativos, uno por cada escenario Gherkin (2 al 5), para mantener trazabilidad entre diseño y ejecución.

Endpoints cubiertos: `POST /v1/login`, `POST /v1/schedule/shift/assign`, `GET /v1/schedule/shift/schedule`, `POST /v1/mdm_psc/punches/replace_punches` y `GET /v1/employee/employee`.

### 3.c Reporte de incidencias

Archivo: `3-bug-report/BUG-001.md` (pendiente). Si no se logra acceso al ambiente, el reporte se presentará como **hipótesis derivada del análisis de la colección**, indicándolo de forma explícita y sin presentarlo como hallazgo ejecutado.

### 4. Bonus

Pendiente de definir entre k6 (carga y estrés) y scripting de API con Vitest.

---

## 4. Supuestos y bloqueos

### Bloqueo: ambiente QA no accesible

Al iniciar el challenge, la URL `https://tk-gr.demo.goodrabbit.tech/` no resolvía. Se verificó desde varias vías para descartar un problema local:

| Vía de verificación | Resultado |
|---|---|
| Google Chrome | `DNS_PROBE_FINISHED_NXDOMAIN` |
| `nslookup tk-gr.demo.goodrabbit.tech 8.8.8.8` (DNS de Google) | `Non-existent domain` |
| `nslookup tk-gr.demo.goodrabbit.tech 1.1.1.1` (DNS de Cloudflare) | `Non-existent domain` |
| Postman, Cloud Agent | `Couldn't resolve host` |
| Postman, Desktop Agent | `getaddrinfo ENOTFOUND tk-gr.demo.goodrabbit.tech` |
| `nslookup goodrabbit.tech 8.8.8.8` | Resuelve |
| `nslookup demo.goodrabbit.tech 8.8.8.8` | Resuelve |

**Conclusión:** los dominios `goodrabbit.tech` y `demo.goodrabbit.tech` existen, pero el subdominio `tk-gr` no está publicado en el DNS público. Las causas posibles son que el ambiente esté apagado, que la URL del enunciado tenga un error, o que requiera VPN o acceso privado.

El bloqueo fue reportado a la reclutadora el 23 de septiembre de 2026. Las capturas y la salida de `nslookup` están en la carpeta `evidencia/`.

> **Actualización:** _(completar si el acceso se restablece: fecha y qué se pudo ejecutar)_

### Supuestos adoptados

1. **Códigos de error:** los códigos HTTP de los escenarios negativos (400/401/404/422) siguen la convención REST y están marcados con `# SUPUESTO` en el `.feature`. Deben validarse contra el ambiente.
2. **Formato de la respuesta del login:** se asume un flujo OAuth2 (`grant_type=password`) que devuelve un campo `access_token`. Los scripts de Postman contemplan también `token` y `data.access_token` por seguridad.
3. **Datos de prueba:** se usan los de la colección entregada (empleado `8`, septiembre de 2026, turno 13:00 a 22:00, zona `America/Santiago`, `repeat: 2`).
4. **Credenciales:** la colección incluye valores de ejemplo en sus variables. No se versionan en este repositorio; se configuran localmente (ver sección 5).
5. **Carga (si se elige k6):** el ambiente es una demo compartida, por lo que se limitará a una carga baja de usuarios virtuales.

---

## 5. Cómo ejecutar

### Requisitos

- Node.js LTS y npm
- Postman
- k6 (solo si se elige el bonus de carga)

### Configuración

1. Importar la colección de `2-postman/` en Postman.
2. En las variables de la colección, completar `username` y `password` con las credenciales entregadas. **No subir credenciales al repositorio.**
3. Verificar que `base_url` apunte a `https://tk-gr.demo.goodrabbit.tech`.
4. Ejecutar primero `[POST] /v1/login`. El token se guarda automáticamente en `bearer_token`.
5. Ejecutar los demás requests, o la colección completa desde el Runner.

---

## 6. Observaciones preliminares (análisis estático de la colección)

Estas observaciones surgen de revisar la colección y **aún no están confirmadas contra el ambiente**:

1. **Header `Content-Type` en el login:** el body es `formdata`, pero el request fija `Content-Type: application/json`. Postman envía además su propio `multipart/form-data`, por lo que el header aparece duplicado en el log. Conviene eliminar el manual.
2. **Zona horaria de los segmentos:** el turno es `13:00 a 22:00` en `America/Santiago`, pero los `segments` se envían en UTC (`13:00:00.000Z`). En septiembre Santiago está en UTC-4, por lo que 13:00 local equivaldría a las 17:00Z. Por confirmar si es un defecto real o un comportamiento intencional.
3. **Nombre inconsistente entre request y response:** se envía `schedule_create` y se recibe `scheduler_create`.
4. **`employee_id` ambiguo en `assign`:** el body lleva `shift.employee_id: 0` y `employee_ids: [8]`. Por confirmar cuál prevalece y qué ocurre con valores contradictorios.
5. **Credenciales en texto plano:** la colección trae usuario y contraseña de ejemplo en sus variables. Es una práctica de riesgo si el archivo se comparte o versiona.

---

## 7. Decisiones

- **Gherkin sin step definitions:** el reto pide diseñar los casos; sin ambiente no habría podido verificarlos. Se priorizó la calidad del diseño, la trazabilidad con Postman y la documentación de supuestos.
- **Un solo flujo, en profundidad:** se prefirió cubrir bien un flujo (login, permisos, datos inválidos, borde) antes que abarcar varios de forma superficial.
- **Transparencia ante el bloqueo:** se documenta qué se verificó, qué es supuesto y qué queda pendiente, en lugar de presentar resultados no ejecutados como si lo estuvieran.

---

## 8. Próximos pasos

- [ ] Completar la colección de Postman con tests y negativos
- [ ] Ejecutar las pruebas si se restablece el acceso al ambiente y reemplazar los `# SUPUESTO`
- [ ] Redactar el bug report (real o simulado, indicándolo)
- [ ] Definir y desarrollar el bonus
- [ ] Preparar la presentación (PPT breve, 45 minutos)