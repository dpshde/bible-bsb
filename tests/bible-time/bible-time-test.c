/* Host checks for bible_format_iso8601. The Flipper build calls this with
 * the clock from furi_hal_rtc_get_datetime. */
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "bible_time.h"

static void test_formats_known_instant(void) {
    char out[32];
    memset(out, 'x', sizeof(out));
    assert(bible_format_iso8601(out, sizeof(out), 2026, 10, 7, 19, 33, 5));
    assert(strcmp(out, "2026-10-07T19:33:05Z") == 0);
}

static void test_leap_day(void) {
    char out[21];
    assert(bible_format_iso8601(out, sizeof(out), 2024, 2, 29, 0, 0, 0));
    assert(strcmp(out, "2024-02-29T00:00:00Z") == 0);
    assert(!bible_format_iso8601(out, sizeof(out), 2023, 2, 29, 0, 0, 0));
    assert(strcmp(out, "2024-02-29T00:00:00Z") == 0);
}

static void test_rejects_out_of_range(void) {
    char out[32];
    strcpy(out, "unchanged");
    assert(!bible_format_iso8601(out, sizeof(out), 10000, 1, 1, 0, 0, 0));
    assert(!bible_format_iso8601(out, sizeof(out), 2026, 0, 1, 0, 0, 0));
    assert(!bible_format_iso8601(out, sizeof(out), 2026, 13, 1, 0, 0, 0));
    assert(!bible_format_iso8601(out, sizeof(out), 2026, 4, 31, 0, 0, 0));
    assert(!bible_format_iso8601(out, sizeof(out), 2026, 1, 1, 24, 0, 0));
    assert(!bible_format_iso8601(out, sizeof(out), 2026, 1, 1, 0, 60, 0));
    assert(!bible_format_iso8601(out, sizeof(out), 2026, 1, 1, 0, 0, 60));
    assert(strcmp(out, "unchanged") == 0);
}

static void test_rejects_short_buffer(void) {
    char out[20];
    memset(out, 'x', sizeof(out));
    assert(!bible_format_iso8601(out, sizeof(out), 2026, 10, 7, 0, 0, 0));
    assert(!bible_format_iso8601(NULL, 32, 2026, 10, 7, 0, 0, 0));
}

int main(void) {
    test_formats_known_instant();
    test_leap_day();
    test_rejects_out_of_range();
    test_rejects_short_buffer();
    printf("bible_time_test: ok\n");
    return 0;
}
