#include "bible_storage.h"
#include "bible_renderer.h"
#include "bible_loader.h"
#include "bible_books.h"

#include <string.h>
#include <stdlib.h>

/* ============================================================================
 * Storage stub — full implementation by storage-collection feature.
 *
 * For now: just shows a toast so ActionMenu / Reader quick-save have
 * visible feedback and compile against a real function.
 * ============================================================================ */

void bible_save_passage(BibleAppState* state) {
    furi_check(state);

    if(state->passage.verse_count == 0) {
        bible_toast_set(&state->toast, "No passage");
        return;
    }

    /* Stub: real implementation will do the full defrag/load/check/write flow */
    bible_toast_set(&state->toast, "Saved!");
}
