//! Kindled Spark — Flipper Zero BSB Scripture Reader

#![no_std]
#![no_main]

extern crate flipperzero_alloc;
extern crate alloc;

use core::ffi::CStr;
use core::mem::MaybeUninit;

use flipperzero_sys::furi::UnsafeRecord;
use flipperzero_rt as rt;
use flipperzero_sys as sys;

mod models;
mod books;
mod bsb_loader;
mod renderer;
mod storage;
mod route_url;
mod nfc_share;
mod views;

use views::{AppState, InputEvent};

rt::manifest!(name = "Kindled Spark");
rt::entry!(main);

extern "C" fn draw_callback(canvas: *mut sys::Canvas, ctx: *mut core::ffi::c_void) {
    let state = unsafe { &mut *(ctx as *mut AppState) };
    unsafe {
        sys::canvas_clear(canvas);
    }
    views::draw_current_view(canvas, state);
}

extern "C" fn input_callback(input_event: *mut sys::InputEvent, ctx: *mut core::ffi::c_void) {
    unsafe {
        let event_queue = ctx as *mut sys::FuriMessageQueue;
        sys::furi_message_queue_put(event_queue, input_event as *mut core::ffi::c_void, 0);
    }
}

fn main(_args: Option<&CStr>) -> i32 {
    unsafe {
        let event_queue = sys::furi_message_queue_alloc(8, core::mem::size_of::<sys::InputEvent>() as u32)
            as *mut sys::FuriMessageQueue;

        let mut state = AppState::new();
        // Preload collection on startup
        state.collection = storage::load_collection();
        let state_ptr = &mut state as *mut AppState;

        let view_port = sys::view_port_alloc();
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
            if sys::furi_message_queue_get(event_queue, event.as_mut_ptr() as *mut core::ffi::c_void, 100)
                == sys::FuriStatusOk
            {
                let ev = event.assume_init();
                if ev.type_ == sys::InputTypePress || ev.type_ == sys::InputTypeRepeat || ev.type_ == sys::InputTypeLong {
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
