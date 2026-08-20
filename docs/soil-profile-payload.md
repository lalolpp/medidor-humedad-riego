# Payload de perfil de suelo — sonda de 100 cm

Cada nodo de perfil contiene diez sensores capacitivos, ubicados cada 10 cm,
y dos sensores PT1000: uno cercano a 30 cm y otro a 70 cm.

## Documento de lectura recomendado

Guardar cada lectura en:

`devices/{deviceId}/readings/{readingId}`

```json
{
  "deviceId": "nodo_perfil_01",
  "ts": "2026-08-19T14:30:00Z",
  "humidityByDepth": {
    "10": 31.8,
    "20": 33.4,
    "30": 35.1,
    "40": 37.0,
    "50": 38.2,
    "60": 39.4,
    "70": 40.0,
    "80": 41.1,
    "90": 41.6,
    "100": 42.3
  },
  "temperature30C": 18.4,
  "temperature70C": 16.9,
  "batteryVoltage": 3.85,
  "batteryPercent": 72,
  "rssi": -68
}
```

## Reglas de datos

- Las profundidades se expresan en centímetros: 10 a 100.
- La humedad es porcentaje calibrado para cada sensor capacitivo.
- Las PT1000 se guardan siempre en grados Celsius, sin depender de la unidad
  elegida por el usuario en la app.
- `ts` se almacena en ISO-8601 UTC. La app también acepta timestamp Unix en
  segundos o milisegundos para mantener compatibilidad con firmware anterior.
- `batteryPercent` se expresa de 0 a 100; la aplicación lo normaliza
  internamente al rango 0 a 1.

## Compatibilidad

La app también entiende payloads planos como `h10`, `h20` … `h100`,
`temp30` y `temp70`. El formato `humidityByDepth` es el recomendado
porque es claro, extensible y más simple de consultar desde Firestore.
