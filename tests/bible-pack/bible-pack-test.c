/* Host checks for the bundled chapter-pack directory lookup. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "bible_pack.h"

static void write_u16(uint8_t* p, uint16_t value) {
    p[0] = (uint8_t)(value & 0xff);
    p[1] = (uint8_t)((value >> 8) & 0xff);
}

static void write_u32(uint8_t* p, uint32_t value) {
    p[0] = (uint8_t)(value & 0xff);
    p[1] = (uint8_t)((value >> 8) & 0xff);
    p[2] = (uint8_t)((value >> 16) & 0xff);
    p[3] = (uint8_t)((value >> 24) & 0xff);
}

static void put_record(
    uint8_t* pack,
    uint16_t index,
    uint8_t book,
    uint8_t chapter,
    uint16_t comp_size,
    uint16_t raw_size,
    uint32_t data_offset) {
    uint8_t* rec = pack + BIBLE_PACK_HEADER_SIZE + (size_t)index * BIBLE_PACK_RECORD_SIZE;
    rec[0] = book;
    rec[1] = chapter;
    write_u16(rec + 2, comp_size);
    write_u16(rec + 4, raw_size);
    write_u32(rec + 6, data_offset);
}

static size_t sample_pack(uint8_t* pack) {
    memset(pack, 0, 64);
    pack[0] = 'B';
    pack[1] = 'S';
    pack[2] = 'B';
    pack[3] = '1';
    write_u16(pack + 4, 3);
    write_u16(pack + 6, BIBLE_PACK_RECORD_SIZE);
    pack[8] = 11;
    pack[9] = 4;
    put_record(pack, 0, 0, 1, 10, 20, 100);
    put_record(pack, 1, 18, 119, 30, 40, 200);
    put_record(pack, 2, 42, 3, 50, 60, 300);
    return BIBLE_PACK_HEADER_SIZE + 3 * BIBLE_PACK_RECORD_SIZE;
}

static void test_finds_ends_and_middle(void) {
    uint8_t pack[64];
    size_t len = sample_pack(pack);
    BiblePackEntry entry;

    assert(bible_pack_find(pack, len, 0, 1, &entry));
    assert(entry.comp_size == 10 && entry.raw_size == 20 && entry.data_offset == 100);

    assert(bible_pack_find(pack, len, 18, 119, &entry));
    assert(entry.book == 18 && entry.chapter == 119);
    assert(entry.comp_size == 30 && entry.raw_size == 40 && entry.data_offset == 200);

    assert(bible_pack_find(pack, len, 42, 3, &entry));
    assert(entry.comp_size == 50 && entry.raw_size == 60 && entry.data_offset == 300);
}

static void test_missing_chapter(void) {
    uint8_t pack[64];
    size_t len = sample_pack(pack);
    BiblePackEntry entry;
    memset(&entry, 0x5a, sizeof(entry));
    assert(!bible_pack_find(pack, len, 0, 2, &entry));
    assert(!bible_pack_find(pack, len, 1, 1, &entry));
    assert(!bible_pack_find(pack, len, 42, 2, &entry));
    assert(!bible_pack_find(pack, len, 0, 0, &entry));
}

static void test_rejects_bad_header(void) {
    uint8_t pack[64];
    size_t len = sample_pack(pack);
    BiblePackEntry entry;

    pack[0] = 'X';
    assert(!bible_pack_find(pack, len, 0, 1, &entry));
    pack[0] = 'B';

    write_u16(pack + 6, 8);
    assert(!bible_pack_find(pack, len, 0, 1, &entry));
    write_u16(pack + 6, BIBLE_PACK_RECORD_SIZE);

    pack[8] = 3;
    assert(!bible_pack_find(pack, len, 0, 1, &entry));
    pack[8] = 11;

    pack[9] = 11;
    assert(!bible_pack_find(pack, len, 0, 1, &entry));
    pack[9] = 4;

    assert(!bible_pack_find(pack, BIBLE_PACK_HEADER_SIZE, 0, 1, &entry));
    assert(!bible_pack_find(NULL, len, 0, 1, &entry));
    assert(!bible_pack_find(pack, len, 0, 1, NULL));
}

static void test_rejects_empty_sizes(void) {
    uint8_t pack[64];
    size_t len = sample_pack(pack);
    put_record(pack, 0, 0, 1, 0, 20, 100);
    BiblePackEntry entry;
    assert(!bible_pack_find(pack, len, 0, 1, &entry));
}

int main(void) {
    test_finds_ends_and_middle();
    test_missing_chapter();
    test_rejects_bad_header();
    test_rejects_empty_sizes();
    puts("bible-pack-test ok");
    return 0;
}
