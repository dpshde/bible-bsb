#pragma once

#include "bible_state.h"

/* ============================================================================
 * Collection storage — read / write / save passage
 *
 * Full implementation will be provided by the storage-collection feature.
 * This header defines the contract so ActionMenu and Reader can call
 * bible_save_passage() today.
 * ============================================================================ */

/**
 * Save the current passage to collection.json.
 *
 * Performs the full save flow:
 * 1. Clears lines (heap defrag)
 * 2. Loads collection from SD if not already loaded
 * 3. Checks for duplicate scripture_ref → toast "Already saved"
 * 4. Appends new entry
 * 5. Writes collection.json via streaming JSON writer
 * 6. Reloads lines (restore reader display)
 * 7. Sets toast "Saved!" or "Save failed"
 *
 * @param state  app state (passage must be valid)
 */
void bible_save_passage(BibleAppState* state);
