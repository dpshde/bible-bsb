/// Views module for Bible [BSB]
use alloc::string::String;
use alloc::vec::Vec;
use flipperzero_sys as sys;

pub mod book_filter;
pub mod book_list;
pub mod chapter_list;
pub mod collection;
pub mod reader;
pub mod verse_select;

pub struct InputEvent {
    pub key: sys::InputKey,
    pub input_type: sys::InputType,
}

#[derive(Clone, Copy, PartialEq)]
pub enum AppView {
    BookList,
    BookFilter,
    ChapterList,
    VerseSelect,
    Reader,
    Collection,
    ActionMenu,
}

pub struct AppState {
    pub current_view: AppView,
    pub selected_book: usize,
    pub selected_chapter: u16,
    pub selected_start_verse: u16,
    pub selected_end_verse: u16,
    pub verse_select_mode: VerseSelectMode,
    pub book_filter_idx: usize,
    pub scroll_offset: usize,
    pub book_scroll: usize,
    pub collection_scroll: usize,
    pub action_menu_selection: usize,
    pub passage: Option<crate::models::Passage>,
    pub collection: Vec<crate::models::CollectionEntry>,
    pub lines: Vec<crate::renderer::Line>,
    pub toast_message: Option<String>,
    pub toast_timer: u32,
    pub reader_came_from_collection: bool,
}

#[derive(Clone, Copy, PartialEq)]
pub enum VerseSelectMode {
    All,
    RangeSelectingStart,
    RangeSelectingEnd,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            current_view: AppView::BookList,
            selected_book: 0,
            selected_chapter: 1,
            selected_start_verse: 1,
            selected_end_verse: 1,
            verse_select_mode: VerseSelectMode::All,
            book_filter_idx: 0,
            scroll_offset: 0,
            book_scroll: 0,
            collection_scroll: 0,
            action_menu_selection: 0,
            passage: None,
            collection: Vec::new(),
            lines: Vec::new(),
            toast_message: None,
            toast_timer: 0,
            reader_came_from_collection: false,
        }
    }

    pub fn set_toast(&mut self, msg: &str) {
        self.toast_message = Some(String::from(msg));
        self.toast_timer = 60; // ~2 seconds at 30fps
    }

    pub fn tick_toast(&mut self) {
        if self.toast_timer > 0 {
            self.toast_timer -= 1;
            if self.toast_timer == 0 {
                self.toast_message = None;
            }
        }
    }
}

pub fn draw_current_view(canvas: *mut sys::Canvas, state: &AppState) {
    match state.current_view {
        AppView::BookList => book_list::draw(canvas, state),
        AppView::BookFilter => book_filter::draw(canvas, state),
        AppView::ChapterList => chapter_list::draw(canvas, state),
        AppView::VerseSelect => verse_select::draw(canvas, state),
        AppView::Reader => reader::draw(canvas, state),
        AppView::Collection => collection::draw(canvas, state),
        AppView::ActionMenu => reader::draw_action_menu(canvas, state),
    }
}

pub fn handle_input(event: &InputEvent, state: &mut AppState) -> bool {
    let quit = match state.current_view {
        AppView::BookList => book_list::handle_input(event, state),
        AppView::BookFilter => book_filter::handle_input(event, state),
        AppView::ChapterList => chapter_list::handle_input(event, state),
        AppView::VerseSelect => verse_select::handle_input(event, state),
        AppView::Reader => reader::handle_input(event, state),
        AppView::Collection => collection::handle_input(event, state),
        AppView::ActionMenu => reader::handle_action_input(event, state),
    };
    state.tick_toast();
    quit
}
