#pragma once

#define PIN_SOIL_SENSOR 34
#define PIN_BATTERY_ADC 35
#define PIN_SOIL_TEMP 27
#define PIN_LTE_PWR 25
#define PIN_VALVE_RELAY 26

#define BATTERY_REF_VOLTAGE 3.3f
#define BATTERY_FULL_VOLTAGE_MV 4200
#define BATTERY_EMPTY_VOLTAGE_MV 3100
#define BATTERY_DIVIDER_GAIN 2.0f

#define DEFAULT_INTERVAL_MIN 30
#define DEFAULT_BATTERY_CAPACITY_MAH 2500
#define DEFAULT_DEVICE_ID "dev0001"

// Máximo de redes WiFi recordadas en NVS (multi-WiFi: casa, oficina, …).
#define MAX_WIFI_NETWORKS 5

// Versión del firmware, comparada con otaVersion remota para decidir OTA.
#define FIRMWARE_VERSION "1.4.0"

#define SLEEP_CURRENT_MAH_PER_DAY 0.7f
#define ACTIVE_MAH_PER_CYCLE 2.1f

#define HISTORY_DIR "/history"
#define HISTORY_MAX_FILES 30
#define HISTORY_CHUNK_RECORDS 20

// Backfill: reenvía a la nube las lecturas acumuladas en LittleFS que no se
// pudieron publicar. BACKFILL_BUDGET_MS limita cuánto tiempo puede alargarse
// el despertar por ciclo; BACKFILL_BATCH_SIZE limita el lote por commit
// Firestore (la API admite hasta 500 escrituras por commit).
#define BACKFILL_BUDGET_MS 10000
#define BACKFILL_BATCH_SIZE 100

#define FIREBASE_HOST "medidor-de-humedad-default-rtdb.firebaseio.com"
#define FIREBASE_API_KEY "AIzaSyCcqtbCigQbxkKJ7zqFxbCuaygvBYTGIYw"

// Credenciales de la cuenta del nodo (email/password para signInWithPassword).
// NO van hardcodeadas aquí: se cargan desde `firmware/include/secrets.h`
// (archivo gitignored). Sin ese archivo, el firmware compila pero NO publica
// en runtime (credenciales vacías), evitando que se fuge la cuenta otra vez.
// Copiar `secrets.h.template` a `secrets.h` y rellenar con las credenciales
// reales (ver "rotación" en el template).
#if __has_include("secrets.h")
#include "secrets.h"
#endif
#ifndef FIREBASE_AUTH_EMAIL
#define FIREBASE_AUTH_EMAIL ""
#endif
#ifndef FIREBASE_AUTH_PASSWORD
#define FIREBASE_AUTH_PASSWORD ""
#endif

#define BLE_DEVICE_NAME "MedidorHumedad"
#define BLE_ADV_WINDOW_MS 30000
#define BLE_KEEP_ALIVE_MS 60000

// Modo banco/pruebas: el nodo no entra en deep sleep, mantiene BLE anunciado
// y repite el ciclo de nube cada samplingIntervalMin (sin martillar Firebase).
// Se activa compilando el entorno esp32dev_ota_debug; NO usar en terreno.
#ifndef DEBUG_ALWAYS_ON
#define DEBUG_ALWAYS_ON 0
#endif

// Válvula/relé de riego accionada por el comando `valveState` de la app
// (devices/{id}/config/current). Con VALVE_KEEP_AWAKE=1, mientras el comando
// sea "ON" el nodo NO entra en deep sleep y mantiene el relé energizado
// (relé común); si se usa un relé biestable (latch), se puede poner 0 y el
// nodo duerme normalmente entre ciclos aplicando el comando en cada despertar.
#define VALVE_KEEP_AWAKE 1
// Mientras riega, re-chequea la nube cada este intervalo para detectar "OFF".
// En banco (`esp32dev_ota_debug`) se reduce a 5 s vía build flags para poder
// probar el relé rápido; en terreno queda 60 s (ahorro de batería).
#ifndef VALVE_RECHECK_MS
#define VALVE_RECHECK_MS 60000
#endif
// Tiempo máximo que la válvula puede estar abierta (minutos). Si se excede,
// el nodo cierra la válvula automáticamente como protección contra inundación.
// 0 = sin límite (no recomendado en producción).
#define VALVE_MAX_OPEN_MIN 240
// Nivel mínimo de batería (0.0–1.0) para accionar la válvula. Si la batería
// está por debajo de este umbral, el nodo ignora el comando ON y duerme para
// proteger la alimentación.
#define VALVE_MIN_BATTERY 0.10
