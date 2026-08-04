# Medidor de Humedad para Riego Tecnificado

Proyecto de sensores de humedad de suelo para riego tecnificado agrícola, con comunicación WiFi, Bluetooth Low Energy (BLE) y datos móviles (SIM/LTE).

## Características

- Medición de humedad de suelo con sensor capacitivo.
- Cada dispositivo es todo-en-uno: ESP32 (WiFi + BLE) + módulo LTE con SIM propia.
- Comunicación por tres vías:
  - **WiFi** para subir datos a la nube.
  - **LTE (SIM)** para subir datos donde no hay WiFi.
  - **BLE** para emparejar, configurar, lectura en vivo y descarga del historial local desde la app móvil.
- **Intervalo de muestreo configurable** (10/15/20/30/60 min) por dispositivo, con **aviso de autonomía
  de batería** al cambiarlo (lecturas más frecuentes = más consumo y más revisión de batería).
- Alimentación: batería 18650 + panel solar (autonomía de ~25 días sin sol a 30 min; ~9–10 días a 10 min).
- Datos en la nube con Firebase (plan gratuito), con roles de usuario final y administrador.
- App móvil con acceso a dispositivos e informes.

## Estado

En fase de **planeación** (BOM definido, arquitectura de datos y energía definidas).

## Estructura del repositorio

```
medidor-humedad-riego/
├── README.md
└── docs/
    ├── architecture.md   # Arquitectura del sistema y flujo de datos
    ├── hardware.md       # BOM (lista de componentes por nodo)
    ├── power-budget.md   # Presupuesto de energía y autonomía
    ├── cloud-firebase.md # Nube, roles y modelo de datos
    └── costs.md          # Costos estimados
```
