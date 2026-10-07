/* Host-side checks for bible_lines_ensure / bible_collection_ensure.
 * Growth goes through bible_heap_grow (malloc first). A failing malloc must
 * return false and leave the previous pointer and capacity alone — callers
 * abort instead of writing through a NULL or undersized buffer.
 *
 * stdlib.h is included before the malloc macro so the libc declaration is
 * not rewritten. bible_state.h then sees the hooked malloc.
 */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int fail_on_call = -1;
static int malloc_calls = 0;

static void* bible_test_malloc(size_t size);

#define malloc(size) bible_test_malloc(size)

#include "bible_state.h"

static void* bible_test_malloc(size_t size) {
    if(fail_on_call >= 0 && malloc_calls >= fail_on_call) {
        return NULL;
    }
    malloc_calls++;
    return (malloc)(size);
}

static void reset_malloc(int fail_after) {
    fail_on_call = fail_after;
    malloc_calls = 0;
}

static void test_lines_ensure_zero_is_noop(void) {
    BibleAppState state;
    bible_app_state_init(&state);
    reset_malloc(-1);

    assert(bible_lines_ensure(&state, 0));
    assert(state.lines == NULL);
    assert(state.lines_capacity == 0);
    assert(malloc_calls == 0);
}

static void test_lines_ensure_grows_in_chunks(void) {
    BibleAppState state;
    bible_app_state_init(&state);
    reset_malloc(-1);

    assert(bible_lines_ensure(&state, 1));
    assert(state.lines != NULL);
    assert(state.lines_capacity == 15);
    assert(malloc_calls == 1);

    BibleLine* first = state.lines;
    state.lines[0].verse_number = 7;
    assert(bible_lines_ensure(&state, 15));
    assert(state.lines == first);
    assert(malloc_calls == 1);

    assert(bible_lines_ensure(&state, 16));
    assert(state.lines != NULL);
    assert(state.lines != first);
    assert(state.lines_capacity == 30);
    assert(state.lines[0].verse_number == 7);
    assert(malloc_calls == 2);

    bible_lines_free(&state);
    assert(state.lines == NULL);
    assert(state.lines_capacity == 0);
    assert(state.line_count == 0);
}

static void test_lines_ensure_oom_preserves_buffer(void) {
    BibleAppState state;
    bible_app_state_init(&state);
    reset_malloc(-1);

    assert(bible_lines_ensure(&state, 1));
    state.lines[0].verse_number = 42;
    memcpy(state.lines[0].text, "keep", 5);
    BibleLine* kept = state.lines;
    uint16_t kept_cap = state.lines_capacity;

    reset_malloc(0);
    assert(!bible_lines_ensure(&state, kept_cap + 1));
    assert(state.lines == kept);
    assert(state.lines_capacity == kept_cap);
    assert(state.lines[0].verse_number == 42);
    assert(strcmp(state.lines[0].text, "keep") == 0);

    bible_lines_free(&state);
}

static void test_lines_ensure_first_alloc_oom(void) {
    BibleAppState state;
    bible_app_state_init(&state);
    reset_malloc(0);

    assert(!bible_lines_ensure(&state, 1));
    assert(state.lines == NULL);
    assert(state.lines_capacity == 0);
}

static void test_collection_ensure_oom_preserves_buffer(void) {
    BibleAppState state;
    bible_app_state_init(&state);
    reset_malloc(-1);

    assert(bible_collection_ensure(&state, 1));
    assert(state.collection != NULL);
    assert(state.collection_capacity == 8);
    memcpy(state.collection[0].scripture_ref, "John.1.1", 9);
    BibleCollectionEntry* kept = state.collection;
    uint8_t kept_cap = state.collection_capacity;

    reset_malloc(0);
    assert(!bible_collection_ensure(&state, (uint16_t)(kept_cap + 1)));
    assert(state.collection == kept);
    assert(state.collection_capacity == kept_cap);
    assert(strcmp(state.collection[0].scripture_ref, "John.1.1") == 0);

    bible_collection_free(&state);
    assert(state.collection == NULL);
    assert(state.collection_capacity == 0);
    assert(state.collection_count == 0);
}

static void test_collection_ensure_first_alloc_oom(void) {
    BibleAppState state;
    bible_app_state_init(&state);
    reset_malloc(0);

    assert(!bible_collection_ensure(&state, 1));
    assert(state.collection == NULL);
    assert(state.collection_capacity == 0);
}

static void test_toast_oom_stays_visible(void) {
    BibleToast toast;
    memset(&toast, 0, sizeof(toast));
    bible_toast_set(&toast, "OOM");
    assert(bible_toast_active(&toast));
    assert(strcmp(toast.message, "OOM") == 0);
}

int main(void) {
    test_lines_ensure_zero_is_noop();
    test_lines_ensure_grows_in_chunks();
    test_lines_ensure_oom_preserves_buffer();
    test_lines_ensure_first_alloc_oom();
    test_collection_ensure_oom_preserves_buffer();
    test_collection_ensure_first_alloc_oom();
    test_toast_oom_stays_visible();
    printf("bible_ensure_test: ok\n");
    return 0;
}
