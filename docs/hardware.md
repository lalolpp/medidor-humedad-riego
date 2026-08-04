# BOM — Lista de componentes por nodo

Presupuesto objetivo: **< $50 USD por nodo** (precios de referencia AliExpress/importación).

| Componente | Modelo sugerido | Precio USD |
|---|---|---|
| Microcontrolador | ESP32 DevKit (WiFi + BLE) | $4–6 |
| Módulo LTE | A7670E (Cat-1 4G) breakout | $18–25 |
| Sensor de humedad | Capacitivo v2.0 (SEN0193) | $2–4 |
| Batería | 18650 (2.500–3.000 mAh) | $3–5 |
| Panel solar | 6V / 2W | $5–7 |
| Carga y regulación | TP4056 + step-up (MT3608) | $2–4 |
| Antena LTE + SIM | Antena + slot SIM | $2–3 |
| Carcasa / PCB | IP65 + placa | $4–6 |
| **Total** | | **~$40–48** |

## Decisión clave: módulo LTE

- **A7670E (Cat-1 4G)** — recomendado: barato y funciona en la red 4G estándar de cualquier operador chileno (Entel, Movistar, WOM). No requiere LTE-M/NB-IoT.
- **NO usar SIM800L (2G)**: las redes 2G/3G están en apagado en Chile; pronto no habrá cobertura.
- **Alternativa**: SIM7000G (Cat-M1/NB-IoT) si se prioriza bajo consumo, pero depende de que la operadora tenga LTE-M desplegado.

## Comunicaciones

- **WiFi + BLE**: integrados en el ESP32.
- **LTE**: módulo A7670E vía UART.
- Se prioriza la vía disponible: WiFi si hay red, LTE como respaldo.
