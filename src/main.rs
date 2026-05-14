//! Kindled Spark — Flipper Zero BSB Scripture Reader

#![no_std]
#![no_main]

extern crate alloc;
extern crate flipperzero_alloc;

use core::ffi::CStr;
use core::mem::MaybeUninit;

use flipperzero_rt as rt;
use flipperzero_sys as sys;
use flipperzero_sys::furi::UnsafeRecord;

mod books;
mod bsb_loader;
mod models;
mod nfc_share;
mod renderer;
mod route_url;
mod storage;
mod views;

use views::{AppState, InputEvent};

rt::manifest!(name = "Kindled Spark", stack_size = 4096);
rt::entry!(main);

extern "C" fn draw_callback(canvas: *mut sys::Canvas, ctx: *mut core::ffi::c_void) {
    if canvas.is_null() || ctx.is_null() {
        return;
    }

    let state = unsafe { &*(ctx as *const AppState) };
    unsafe {
        sys::canvas_clear(canvas);
    }
    views::draw_current_view(canvas, state);
}

extern "C" fn input_callback(input_event: *mut sys::InputEvent, ctx: *mut core::ffi::c_void) {
    if input_event.is_null() || ctx.is_null() {
        return;
    }

    unsafe {
        let event_queue = ctx as *mut sys::FuriMessageQueue;
        sys::furi_message_queue_put(event_queue, input_event as *mut core::ffi::c_void, 0);
    }
}

fn main(_args: Option<&CStr>) -> i32 {
    unsafe {
        let event_queue =
            sys::furi_message_queue_alloc(8, core::mem::size_of::<sys::InputEvent>() as u32);
        if event_queue.is_null() {
            return -1;
        }

        let mut state = AppState::new();
        state.collection = storage::load_collection();
        let state_ptr = &mut state as *mut AppState;

        let view_port = sys::view_port_alloc();
        if view_port.is_null() {
            sys::furi_message_queue_free(event_queue);
            return -1;
        }

        sys::view_port_draw_callback_set(
            view_port,
            Some(draw_callback),
            state_ptr as *mut core::ffi::c_void,
        );
        sys::view_port_input_callback_set(
            view_port,
            Some(input_callback),
            event_queue as *mut core::ffi::c_void,
        );

        let gui = UnsafeRecord::open(c"gui");
        sys::gui_add_view_port(gui.as_ptr(), view_port, sys::GuiLayerFullscreen);

        let mut event: MaybeUninit<sys::InputEvent> = MaybeUninit::uninit();
        let mut running = true;

        while running {
            if sys::furi_message_queue_get(
                event_queue,
                event.as_mut_ptr() as *mut core::ffi::c_void,
                100,
            ) == sys::FuriStatusOk
            {
                let ev = event.assume_init();
                if ev.type_ == sys::InputTypePress
                    || ev.type_ == sys::InputTypeRepeat
                    || ev.type_ == sys::InputTypeLong
                {
                    let ie = InputEvent {
                        key: ev.key,
                        input_type: ev.type_,
                    };
                    if views::handle_input(&ie, &mut state) {
                        running = false;
                    }
                }
            }
            sys::view_port_update(view_port);
        }

        sys::view_port_enabled_set(view_port, false);
        sys::gui_remove_view_port(gui.as_ptr(), view_port);
        sys::view_port_free(view_port);
        sys::furi_message_queue_free(event_queue);
    }

    0
}
