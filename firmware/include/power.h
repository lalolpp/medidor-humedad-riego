#pragma once

#include <stdint.h>

bool isValidInterval(uint16_t intervalMin);
float autonomyDays(uint16_t intervalMin, uint16_t capacityMah, float batteryLevel01);
