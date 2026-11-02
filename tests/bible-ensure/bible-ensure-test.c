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
#include "bible_books.h"

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

static void test_chapter_and_book_boundary_navigation(void) {
    uint8_t next_book = 0;
    uint16_t next_ch = 0;

    /* Same-book chapter advance: Genesis 1 -> Genesis 2 */
    assert(bible_next_chapter(0, 1, &next_book, &next_ch));
    assert(next_book == 0 && next_ch == 2);

    /* Book boundary advance: Genesis 50 -> Exodus 1 */
    assert(bible_next_chapter(0, 50, &next_book, &next_ch));
    assert(next_book == 1 && next_ch == 1);

    /* Single-chapter book advance: Obadiah 1 (index 30) -> Jonah 1 (index 31) */
    assert(bible_next_chapter(30, 1, &next_book, &next_ch));
    assert(next_book == 31 && next_ch == 1);

    /* OT to NT boundary: Malachi 4 (index 38) -> Matthew 1 (index 39) */
    assert(bible_next_chapter(38, 4, &next_book, &next_ch));
    assert(next_book == 39 && next_ch == 1);

    /* End of Bible: Revelation 22 (index 65) has no next chapter */
    assert(!bible_next_chapter(65, 22, &next_book, &next_ch));

    /* Start of Bible: Genesis 1 has no previous chapter */
    uint8_t prev_book = 0;
    uint16_t prev_ch = 0;
    assert(!bible_prev_chapter(0, 1, &prev_book, &prev_ch));

    /* Book boundary retreat: Exodus 1 -> Genesis 50 */
    assert(bible_prev_chapter(1, 1, &prev_book, &prev_ch));
    assert(prev_book == 0 && prev_ch == 50);

    /* Traverse all 1,189 chapters forward from Genesis 1 to Revelation 22, then backward */
    uint8_t book = 0;
    uint16_t ch = 1;
    uint16_t count = 1;
    while(bible_next_chapter(book, ch, &next_book, &next_ch)) {
        book = next_book;
        ch = next_ch;
        count++;
    }
    assert(book == 65 && ch == 22);
    assert(count == 1189);

    while(bible_prev_chapter(book, ch, &prev_book, &prev_ch)) {
        book = prev_book;
        ch = prev_ch;
        count--;
    }
    assert(book == 0 && ch == 1);
    assert(count == 1);
}

static void test_testament_and_genre_hierarchy(void) {
    uint8_t genres[BIBLE_GENRE_COUNT];
    uint8_t ot_genres = get_genres_for_testament(0, genres);
    assert(ot_genres == 5);
    assert(genres[0] == 0 && genres[4] == 4);

    uint8_t nt_genres = get_genres_for_testament(1, genres);
    assert(nt_genres == 5);
    assert(genres[0] == 5 && genres[4] == 9);

    /* Every book 0..65 belongs to exactly one genre in contiguous order */
    uint8_t total_books = 0;
    for(uint8_t g = 0; g < BIBLE_GENRE_COUNT; g++) {
        uint8_t books[BIBLE_BOOK_COUNT];
        uint8_t b_count = get_books_for_genre(g, books);
        assert(b_count > 0);
        for(uint8_t i = 0; i < b_count; i++) {
            assert(books[i] == total_books);
            assert(get_genre_for_book(books[i]) == g);
            total_books++;
        }
    }
    assert(total_books == BIBLE_BOOK_COUNT);
}

int main(void) {
    test_lines_ensure_zero_is_noop();
    test_lines_ensure_grows_in_chunks();
    test_lines_ensure_oom_preserves_buffer();
    test_lines_ensure_first_alloc_oom();
    test_collection_ensure_oom_preserves_buffer();
    test_collection_ensure_first_alloc_oom();
    test_toast_oom_stays_visible();
    test_chapter_and_book_boundary_navigation();
    test_testament_and_genre_hierarchy();
    printf("bible_ensure_test: ok\n");
    return 0;
}
