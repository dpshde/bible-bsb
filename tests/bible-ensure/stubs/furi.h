#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define furi_check(expr)           \
    do {                           \
        if(!(expr)) {              \
            abort();               \
        }                          \
    } while(0)
