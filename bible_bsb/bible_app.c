#include "bible_app.h"
#include "bible_view_book_list.h"
#include "bible_view_book_filter.h"

#include <furi.h>
#include <gui/gui.h>
#include <gui/view_dispatcher.h>
#include <gui/scene_manager.h>
#include <gui/view.h>

/* ============================================================================
 * Scene handlers — stubs for skeleton (real logic added in later features)
 * ============================================================================ */

static void bible_bsb_scene_book_list_on_enter(void* context) {
    BibleApp* app = context;
    view_dispatcher_switch_to_view(app->view_dispatcher, BibleViewBookList);
}

static bool bible_bsb_scene_book_list_on_event(void* context, SceneManagerEvent event) {
    UNUSED(context);
    UNUSED(event);
    return false;
}

static void bible_bsb_scene_book_list_on_exit(void* context) {
    UNUSED(context);
}

static void bible_bsb_scene_book_filter_on_enter(void* context) {
    BibleApp* app = context;
    view_dispatcher_switch_to_view(app->view_dispatcher, BibleViewBookFilter);
}

static bool bible_bsb_scene_book_filter_on_event(void* context, SceneManagerEvent event) {
    UNUSED(context);
    UNUSED(event);
    return false;
}

static void bible_bsb_scene_book_filter_on_exit(void* context) {
    UNUSED(context);
}

static void bible_bsb_scene_chapter_list_on_enter(void* context) {
    BibleApp* app = context;
    view_dispatcher_switch_to_view(app->view_dispatcher, BibleViewChapterList);
}

static bool bible_bsb_scene_chapter_list_on_event(void* context, SceneManagerEvent event) {
    UNUSED(context);
    UNUSED(event);
    return false;
}

static void bible_bsb_scene_chapter_list_on_exit(void* context) {
    UNUSED(context);
}

static void bible_bsb_scene_verse_select_on_enter(void* context) {
    BibleApp* app = context;
    view_dispatcher_switch_to_view(app->view_dispatcher, BibleViewVerseSelect);
}

static bool bible_bsb_scene_verse_select_on_event(void* context, SceneManagerEvent event) {
    UNUSED(context);
    UNUSED(event);
    return false;
}

static void bible_bsb_scene_verse_select_on_exit(void* context) {
    UNUSED(context);
}

static void bible_bsb_scene_reader_on_enter(void* context) {
    BibleApp* app = context;
    view_dispatcher_switch_to_view(app->view_dispatcher, BibleViewReader);
}

static bool bible_bsb_scene_reader_on_event(void* context, SceneManagerEvent event) {
    UNUSED(context);
    UNUSED(event);
    return false;
}

static void bible_bsb_scene_reader_on_exit(void* context) {
    UNUSED(context);
}

static void bible_bsb_scene_action_menu_on_enter(void* context) {
    BibleApp* app = context;
    view_dispatcher_switch_to_view(app->view_dispatcher, BibleViewActionMenu);
}

static bool bible_bsb_scene_action_menu_on_event(void* context, SceneManagerEvent event) {
    UNUSED(context);
    UNUSED(event);
    return false;
}

static void bible_bsb_scene_action_menu_on_exit(void* context) {
    UNUSED(context);
}

static void bible_bsb_scene_collection_on_enter(void* context) {
    BibleApp* app = context;
    view_dispatcher_switch_to_view(app->view_dispatcher, BibleViewCollection);
}

static bool bible_bsb_scene_collection_on_event(void* context, SceneManagerEvent event) {
    UNUSED(context);
    UNUSED(event);
    return false;
}

static void bible_bsb_scene_collection_on_exit(void* context) {
    UNUSED(context);
}

static void bible_bsb_scene_nfc_share_on_enter(void* context) {
    BibleApp* app = context;
    view_dispatcher_switch_to_view(app->view_dispatcher, BibleViewNfcShare);
}

static bool bible_bsb_scene_nfc_share_on_event(void* context, SceneManagerEvent event) {
    UNUSED(context);
    UNUSED(event);
    return false;
}

static void bible_bsb_scene_nfc_share_on_exit(void* context) {
    UNUSED(context);
}

/* ============================================================================
 * SceneManagerHandlers array
 * ============================================================================ */
static const AppSceneOnEnterCallback bible_bsb_on_enter_handlers[BibleSceneCount] = {
    bible_bsb_scene_book_list_on_enter,
    bible_bsb_scene_book_filter_on_enter,
    bible_bsb_scene_chapter_list_on_enter,
    bible_bsb_scene_verse_select_on_enter,
    bible_bsb_scene_reader_on_enter,
    bible_bsb_scene_action_menu_on_enter,
    bible_bsb_scene_collection_on_enter,
    bible_bsb_scene_nfc_share_on_enter,
};

static const AppSceneOnEventCallback bible_bsb_on_event_handlers[BibleSceneCount] = {
    bible_bsb_scene_book_list_on_event,
    bible_bsb_scene_book_filter_on_event,
    bible_bsb_scene_chapter_list_on_event,
    bible_bsb_scene_verse_select_on_event,
    bible_bsb_scene_reader_on_event,
    bible_bsb_scene_action_menu_on_event,
    bible_bsb_scene_collection_on_event,
    bible_bsb_scene_nfc_share_on_event,
};

static const AppSceneOnExitCallback bible_bsb_on_exit_handlers[BibleSceneCount] = {
    bible_bsb_scene_book_list_on_exit,
    bible_bsb_scene_book_filter_on_exit,
    bible_bsb_scene_chapter_list_on_exit,
    bible_bsb_scene_verse_select_on_exit,
    bible_bsb_scene_reader_on_exit,
    bible_bsb_scene_action_menu_on_exit,
    bible_bsb_scene_collection_on_exit,
    bible_bsb_scene_nfc_share_on_exit,
};

static const SceneManagerHandlers bible_bsb_scene_handlers = {
    .on_enter_handlers = bible_bsb_on_enter_handlers,
    .on_event_handlers = bible_bsb_on_event_handlers,
    .on_exit_handlers = bible_bsb_on_exit_handlers,
    .scene_num = BibleSceneCount,
};

/* ============================================================================
 * Custom view draw callbacks — minimal stubs
 * ============================================================================ */

static void bible_bsb_wrapper_book_filter_draw(Canvas* canvas, void* ctx) {
    bible_bsb_view_book_filter_draw(canvas, ctx);
}

static bool bible_bsb_wrapper_book_filter_input(InputEvent* event, void* ctx) {
    return bible_bsb_view_book_filter_input(event, ctx);
}

static void bible_bsb_view_chapter_list_draw(Canvas* canvas, void* ctx) {
    UNUSED(ctx);
    canvas_clear(canvas);
    canvas_set_font(canvas, FontPrimary);
    canvas_draw_str(canvas, 2, 10, "Chapter List");
}

static bool bible_bsb_view_chapter_list_input(InputEvent* event, void* ctx) {
    UNUSED(event);
    UNUSED(ctx);
    return false;
}

static void bible_bsb_view_verse_select_draw(Canvas* canvas, void* ctx) {
    UNUSED(ctx);
    canvas_clear(canvas);
    canvas_set_font(canvas, FontPrimary);
    canvas_draw_str(canvas, 2, 10, "Verse Select");
}

static bool bible_bsb_view_verse_select_input(InputEvent* event, void* ctx) {
    UNUSED(event);
    UNUSED(ctx);
    return false;
}

static void bible_bsb_view_reader_draw(Canvas* canvas, void* ctx) {
    UNUSED(ctx);
    canvas_clear(canvas);
    canvas_set_font(canvas, FontPrimary);
    canvas_draw_str(canvas, 2, 10, "Reader");
}

static bool bible_bsb_view_reader_input(InputEvent* event, void* ctx) {
    UNUSED(event);
    UNUSED(ctx);
    return false;
}

static void bible_bsb_view_action_menu_draw(Canvas* canvas, void* ctx) {
    UNUSED(ctx);
    canvas_clear(canvas);
    canvas_set_font(canvas, FontPrimary);
    canvas_draw_str(canvas, 2, 10, "Action Menu");
}

static bool bible_bsb_view_action_menu_input(InputEvent* event, void* ctx) {
    UNUSED(event);
    UNUSED(ctx);
    return false;
}

static void bible_bsb_view_collection_draw(Canvas* canvas, void* ctx) {
    UNUSED(ctx);
    canvas_clear(canvas);
    canvas_set_font(canvas, FontPrimary);
    canvas_draw_str(canvas, 2, 10, "Collection");
}

static bool bible_bsb_view_collection_input(InputEvent* event, void* ctx) {
    UNUSED(event);
    UNUSED(ctx);
    return false;
}

static void bible_bsb_view_nfc_share_draw(Canvas* canvas, void* ctx) {
    UNUSED(ctx);
    canvas_clear(canvas);
    canvas_set_font(canvas, FontPrimary);
    canvas_draw_str(canvas, 2, 10, "NFC Share");
}

static bool bible_bsb_view_nfc_share_input(InputEvent* event, void* ctx) {
    UNUSED(event);
    UNUSED(ctx);
    return false;
}

/* ============================================================================
 * Allocation
 * ============================================================================ */
BibleApp* bible_app_alloc(void) {
    BibleApp* app = malloc(sizeof(BibleApp));
    furi_check(app);
    memset(app, 0, sizeof(BibleApp));

    /* App state */
    app->state = malloc(sizeof(BibleAppState));
    furi_check(app->state);
    bible_app_state_init(app->state);

    /* ViewDispatcher + SceneManager */
    app->view_dispatcher = view_dispatcher_alloc();
    app->scene_manager = scene_manager_alloc(&bible_bsb_scene_handlers, app);
    view_dispatcher_set_event_callback_context(app->view_dispatcher, app);
    view_dispatcher_set_custom_event_callback(
        app->view_dispatcher, NULL); /* set per-scene later */
    view_dispatcher_set_navigation_event_callback(
        app->view_dispatcher, NULL); /* set per-scene later */

    /* GUI */
    app->gui = furi_record_open(RECORD_GUI);
    view_dispatcher_attach_to_gui(app->view_dispatcher, app->gui, ViewDispatcherTypeFullscreen);

    /* Custom views */
    View* view;

    view = view_alloc();
    view_set_draw_callback(view, bible_bsb_view_book_list_draw);
    view_set_input_callback(view, bible_bsb_view_book_list_input);
    view_set_context(view, app);
    app->views[BibleViewBookList] = view;
    view_dispatcher_add_view(app->view_dispatcher, BibleViewBookList, view);

    view = view_alloc();
    view_set_draw_callback(view, bible_bsb_wrapper_book_filter_draw);
    view_set_input_callback(view, bible_bsb_wrapper_book_filter_input);
    view_set_context(view, app);
    app->views[BibleViewBookFilter] = view;
    view_dispatcher_add_view(app->view_dispatcher, BibleViewBookFilter, view);

    view = view_alloc();
    view_set_draw_callback(view, bible_bsb_view_chapter_list_draw);
    view_set_input_callback(view, bible_bsb_view_chapter_list_input);
    view_set_context(view, app);
    app->views[BibleViewChapterList] = view;
    view_dispatcher_add_view(app->view_dispatcher, BibleViewChapterList, view);

    view = view_alloc();
    view_set_draw_callback(view, bible_bsb_view_verse_select_draw);
    view_set_input_callback(view, bible_bsb_view_verse_select_input);
    view_set_context(view, app);
    app->views[BibleViewVerseSelect] = view;
    view_dispatcher_add_view(app->view_dispatcher, BibleViewVerseSelect, view);

    view = view_alloc();
    view_set_draw_callback(view, bible_bsb_view_reader_draw);
    view_set_input_callback(view, bible_bsb_view_reader_input);
    view_set_context(view, app);
    app->views[BibleViewReader] = view;
    view_dispatcher_add_view(app->view_dispatcher, BibleViewReader, view);

    view = view_alloc();
    view_set_draw_callback(view, bible_bsb_view_action_menu_draw);
    view_set_input_callback(view, bible_bsb_view_action_menu_input);
    view_set_context(view, app);
    app->views[BibleViewActionMenu] = view;
    view_dispatcher_add_view(app->view_dispatcher, BibleViewActionMenu, view);

    view = view_alloc();
    view_set_draw_callback(view, bible_bsb_view_collection_draw);
    view_set_input_callback(view, bible_bsb_view_collection_input);
    view_set_context(view, app);
    app->views[BibleViewCollection] = view;
    view_dispatcher_add_view(app->view_dispatcher, BibleViewCollection, view);

    view = view_alloc();
    view_set_draw_callback(view, bible_bsb_view_nfc_share_draw);
    view_set_input_callback(view, bible_bsb_view_nfc_share_input);
    view_set_context(view, app);
    app->views[BibleViewNfcShare] = view;
    view_dispatcher_add_view(app->view_dispatcher, BibleViewNfcShare, view);

    return app;
}

/* ============================================================================
 * Free — mirror alloc order in reverse
 * ============================================================================ */
void bible_app_free(BibleApp* app) {
    furi_check(app);

    /* Remove all views from dispatcher before freeing them */
    for(BibleView v = 0; v < BibleViewCount; v++) {
        View* view = app->views[v];
        if(view != NULL) {
            view_dispatcher_remove_view(app->view_dispatcher, v);
            view_free(view);
        }
    }

    /* GUI */
    furi_record_close(RECORD_GUI);

    /* Dispatcher + SceneManager */
    view_dispatcher_free(app->view_dispatcher);
    scene_manager_free(app->scene_manager);

    /* State */
    free(app->state);
    free(app);
}

/* ============================================================================
 * Entry point
 * ============================================================================ */
int32_t bible_bsb_main(void* p) {
    UNUSED(p);

    BibleApp* app = bible_app_alloc();
    if(app == NULL) {
        return -1;
    }

    scene_manager_next_scene(app->scene_manager, BibleSceneBookList);
    view_dispatcher_run(app->view_dispatcher);

    bible_app_free(app);
    return 0;
}
