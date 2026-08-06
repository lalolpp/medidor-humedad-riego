#pragma once

#define PIN_SOIL_SENSOR 34
#define PIN_BATTERY_ADC 35
#define PIN_SOIL_TEMP 27
#define PIN_LTE_PWR 25

#define BATTERY_REF_VOLTAGE 3.3f
#define BATTERY_FULL_VOLTAGE_MV 4200
#define BATTERY_EMPTY_VOLTAGE_MV 3100
#define BATTERY_DIVIDER_GAIN 2.0f

#define DEFAULT_INTERVAL_MIN 30
#define DEFAULT_BATTERY_CAPACITY_MAH 2500
#define DEFAULT_DEVICE_ID "dev0001"

// Versión del firmware, comparada con otaVersion remota para decidir OTA.
#define FIRMWARE_VERSION "1.0.0"

#define SLEEP_CURRENT_MAH_PER_DAY 0.7f
#define ACTIVE_MAH_PER_CYCLE 2.1f

#define HISTORY_DIR "/history"
#define HISTORY_MAX_FILES 30
#define HISTORY_CHUNK_RECORDS 20

#define FIREBASE_HOST "medidor-de-humedad-default-rtdb.firebaseio.com"
#define FIREBASE_API_KEY "AIzaSyCcqtbCigQbxkKJ7zqFxbCuaygvBYTGIYw"
#define FIREBASE_AUTH_EMAIL "nodo@medidor.cl"
#define FIREBASE_AUTH_PASSWORD "Medidor2026Nodo"

#define BLE_DEVICE_NAME "MedidorHumedad"
#define BLE_ADV_WINDOW_MS 30000
#define BLE_KEEP_ALIVE_MS 60000
