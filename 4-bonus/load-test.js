// Reto QA GoodRabbit - Bonus: Pruebas de carga y estrés (k6)
// Objetivo: medir latencia y tasa de error de los endpoints identificados como entos en el analisis manual (BUG-002.md): POST /v1/login y POST /v1/mdm_psc/punches/replace_punches, bajo carga concurrente baja

// Como ejecutar:
//   1. Instalar k6: https://k6.io/docs/get-started/installation/
//   2. Definir las credenciales como variables de entorno (NUNCA hardcodear):
//      $env:BASE_URL="https://demo.timekeeper.goodrabbit.tech"
//      $env:QA_USER="admin"
//      $env:QA_PASS="contraseña"
//   3. Ejecutar: k6 run 4-bonus/load-test.js
//
// El script NO trae credenciales por defecto a proposito: si faltan, falla rapido con un mensaje claro en vez de intentar autenticar con valores vacios.

import http from "k6/http";
import { check, sleep, group } from "k6";
import { Trend, Rate, Counter } from "k6/metrics";

// ---------------------------------------------------------------------------
// Configuracion

const BASE_URL = __ENV.BASE_URL || "https://demo.timekeeper.goodrabbit.tech";
const USERNAME = __ENV.QA_USER;
const PASSWORD = __ENV.QA_PASS;
// client_id correcto para este ambiente (ver README, seccion "Bloqueo inicial"). No es un secreto: es el identificador publico del cliente OAuth, visible en cualquier request del propio Dashboard Web.
const CLIENT_ID = __ENV.QA_CLIENT_ID || "67d6c2ddad5a48b8ac66a34e4b3fff00";
const EMPLOYEE_ID = __ENV.QA_EMPLOYEE_ID || "1";

if (!USERNAME || !PASSWORD) {
  throw new Error(
    "Faltan las variables de entorno QA_USER y/o QA_PASS. " +
    "Definelas antes de ejecutar (ver comentario superior)."
  );
}

// Carga baja e intencional: el ambiente es una demo compartida con GoodRabbit y otros postulantes, no un ambiente dedicado de performance. El objetivo es observar el comportamiento bajo un poco de concurrencia, no estresarlo.
export const options = {
  scenarios: {
    login_load: {
      executor: "ramping-vus",
      exec: "loginScenario",
      startVUs: 0,
      stages: [
        { duration: "20s", target: 5 },  // sube a 5 usuarios virtuales
        { duration: "40s", target: 5 },  // sostiene 5 usuarios
        { duration: "10s", target: 0 },  // baja a 0
      ],
      gracefulRampDown: "5s",
    },
    replace_punches_load: {
      executor: "ramping-vus",
      exec: "replacePunchesScenario",
      startVUs: 0,
      stages: [
        { duration: "20s", target: 5 },
        { duration: "40s", target: 5 },
        { duration: "10s", target: 0 },
      ],
      gracefulRampDown: "5s",
      startTime: "1m15s", // corre despues del escenario de login, para no mezclar metricas
    },
  },
  thresholds: {
    // Umbrales generosos a proposito: ya sabemos (BUG-002) que el ambiente responde en 10-18s en solicitudes individuales. El objetivo de estos thresholds es detectar si la carga concurrente lo EMPEORA aun mas, no exigir un tiempo "ideal" que ya sabemos que no cumple hoy.
    "http_req_duration{endpoint:login}": ["p(95)<25000"],
    "http_req_duration{endpoint:replace_punches}": ["p(95)<20000"],
    "login_errors": ["rate<0.1"],
    "replace_punches_errors": ["rate<0.1"],
  },
};

// ---------------------------------------------------------------------------
// Metricas custom

const loginDuration = new Trend("login_duration_ms", true);
const loginErrors = new Rate("login_errors");
const loginSuccessCount = new Counter("login_success_total");

// Contador global de muestras de diagnostico registradas (no reinicia entre VUs en k6 porque cada VU corre en su propio contexto de script, asi que en la practica cada VU logueara sus propios primeros N fallos).
let loginFailSampleCount = 0;
const MAX_FAIL_SAMPLES = 5;

const replacePunchesDuration = new Trend("replace_punches_duration_ms", true);
const replacePunchesErrors = new Rate("replace_punches_errors");
const replacePunchesSuccessCount = new Counter("replace_punches_success_total");

// ---------------------------------------------------------------------------
// Escenario 1: POST /v1/login

export function loginScenario() {
  group("Login", () => {
    const url = `${BASE_URL}/v1/login`;
    const payload = {
      username: USERNAME,
      password: PASSWORD,
      grant_type: "password",
      client_id: CLIENT_ID,
      scope: "timekeeper schedule employee auth mdm_psc custom_reports",
    };

    const res = http.post(url, payload, {
      tags: { endpoint: "login" },
    });

    loginDuration.add(res.timings.duration);

    const ok = check(res, {
      "login: status 200": (r) => r.status === 200,
      "login: devuelve access_token": (r) => {
        try {
          return !!r.json("access_token");
        } catch (e) {
          return false;
        }
      },
    });

    loginErrors.add(!ok);
    if (ok) {
      loginSuccessCount.add(1);
    } else if (loginFailSampleCount < MAX_FAIL_SAMPLES) {
      // Diagnostico: registra codigo y cuerpo de los primeros fallos para identificar la causa raiz (rate limiting, sesion unica, colapso, etc.)
      loginFailSampleCount++;
      console.log(
        `[LOGIN FAIL #${loginFailSampleCount}] status=${res.status} duration=${res.timings.duration}ms body=${res.body ? res.body.slice(0, 300) : "(vacio)"}`
      );
    }
  });

  sleep(1);
}

// ---------------------------------------------------------------------------
// Escenario 2: POST /v1/mdm_psc/punches/replace_punches
// Requiere autenticarse primero para obtener el token de este VU.

export function replacePunchesScenario() {
  let token = null;

  group("Login previo (requerido para replace_punches)", () => {
    const loginRes = http.post(
      `${BASE_URL}/v1/login`,
      {
        username: USERNAME,
        password: PASSWORD,
        grant_type: "password",
        client_id: CLIENT_ID,
        scope: "timekeeper schedule employee auth mdm_psc custom_reports",
      },
      { tags: { endpoint: "login_setup" } }
    );
    if (loginRes.status === 200) {
      try {
        token = loginRes.json("access_token");
      } catch (e) {
        token = null;
      }
    }
  });

  if (!token) {
    replacePunchesErrors.add(true);
    return;
  }

  group("Replace punches", () => {
    const url = `${BASE_URL}/v1/mdm_psc/punches/replace_punches`;
    // punch_dtm unico por iteracion (timestamp) para no chocar entre VUs
    const uniqueDtm = new Date(Date.now()).toISOString().slice(0, 19);
    const body = JSON.stringify({
      disable_ids: [],
      punches: [
        {
          punch_dtm: uniqueDtm,
          employee_id: Number(EMPLOYEE_ID),
          device_id: -1,
          in_out: true,
          online: true,
          type_autentification: "finger",
          timezone: "America/Santiago",
          extra_data: "k6-load-test",
        },
      ],
    });

    const res = http.post(url, body, {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      tags: { endpoint: "replace_punches" },
    });

    replacePunchesDuration.add(res.timings.duration);

    const ok = check(res, {
      "replace_punches: status 200": (r) => r.status === 200,
      "replace_punches: created_punches = 1": (r) => {
        try {
          return r.json("data.created_punches") === 1;
        } catch (e) {
          return false;
        }
      },
    });

    replacePunchesErrors.add(!ok);
    if (ok) replacePunchesSuccessCount.add(1);
  });

  sleep(1);
}