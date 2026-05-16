#include "bible_nfc.h"

#include <furi.h>

/* ============================================================================
 * NFC stub — full implementation by nfc-share-view feature.
 *
 * For now: just sets flags so ActionMenu can compile and link.
 * The real implementation will allocate nfc, device, listener, etc.
 * ============================================================================ */

bool bible_nfc_start_url(BibleAppState* state) {
    furi_check(state);

    if(state->nfc_url[0] == '\0') {
        return false;
    }

    state->nfc_emitting = true;
    state->nfc_is_export = false;

    /* Stub: real implementation starts NTAG215 emulation here */
    return true;
}

bool bible_nfc_start_text(BibleAppState* state, const char* text) {
    furi_check(state);
    furi_check(text);

    /* NTAG215 payload capacity is ~500 bytes after system pages and TLV overhead */
    if(strlen(text) > 480) {
        return false;
    }

    strlcpy(state->nfc_url, "Export JSON", sizeof(state->nfc_url));
    state->nfc_emitting = true;
    state->nfc_is_export = true;

    /* Stub: real implementation starts NTAG215 NDEF Text emulation here */
    return true;
}

void bible_nfc_stop(BibleAppState* state) {
    furi_check(state);

    state->nfc_emitting = false;
    state->nfc_url[0] = '\0';
    state->nfc_is_export = false;

    /* Stub: real implementation stops listener, frees device, etc. */
}
