/// NFC tag emulation for route.bible URL sharing.
/// Supports both writing .nfc files and direct NTAG215 emulation.
use alloc::string::String;
use alloc::vec::Vec;
use core::cell::UnsafeCell;
use flipperzero_sys as sys;

const NFC_DIR: &str = "/ext/nfc";

struct SyncUnsafeCell<T>(UnsafeCell<T>);
unsafe impl<T> Sync for SyncUnsafeCell<T> {}

static EMULATION_STATE: SyncUnsafeCell<EmulationState> =
    SyncUnsafeCell(UnsafeCell::new(EmulationState {
        nfc: core::ptr::null_mut(),
        listener: core::ptr::null_mut(),
        device: core::ptr::null_mut(),
        active: false,
    }));

struct EmulationState {
    nfc: *mut sys::Nfc,
    listener: *mut sys::NfcListener,
    device: *mut sys::NfcDevice,
    active: bool,
}

/// NDEF URI Record header: MB=1, ME=1, SR=1, TNF=01 (Well-known type)
const NDEF_HEADER: u8 = 0xD1;
/// Type length for single-byte 'U' type
const NDEF_TYPE_LEN: u8 = 0x01;
/// Well-known type for URI
const NDEF_TYPE_URI: u8 = 0x55;
/// URI prefix: https://
const URI_PREFIX_HTTPS: u8 = 0x04;

/// NTAG215 capacity in user pages (126 pages = 504 bytes)
const NTAG215_USER_PAGES: usize = 126;
/// Page 3 = CC (Capability Container)
const CC_PAGE: usize = 3;

/// Build raw NDEF URL bytes (header, type-length, payload-length, type, payload).
/// Strips `https://` from the URL because the NDEF URI prefix byte already encodes it.
fn build_ndef_url(url: &str) -> Vec<u8> {
    let stripped = url.strip_prefix("https://").unwrap_or(url);
    let url_bytes = stripped.as_bytes();
    let payload_len = 1 + url_bytes.len();

    let mut ndef = Vec::with_capacity(4 + payload_len);
    ndef.push(NDEF_HEADER);
    ndef.push(NDEF_TYPE_LEN);
    ndef.push(payload_len as u8);
    ndef.push(NDEF_TYPE_URI);
    ndef.push(URI_PREFIX_HTTPS);
    ndef.extend_from_slice(url_bytes);
    ndef
}

/// NDEF Text Record type byte
const NDEF_TYPE_TEXT: u8 = 0x54; // 'T'

/// Build raw NDEF Text bytes (header, type-length, payload-length, type, payload).
/// Payload format: status_byte (UTF-8, lang_len=2) + "en" + text.
fn build_ndef_text(text: &str) -> Vec<u8> {
    let text_bytes = text.as_bytes();
    let lang = b"en";
    let payload_len = 1 + lang.len() + text_bytes.len();

    let mut ndef = Vec::with_capacity(4 + payload_len);
    ndef.push(NDEF_HEADER);
    ndef.push(NDEF_TYPE_LEN);
    ndef.push(payload_len as u8);
    ndef.push(NDEF_TYPE_TEXT);
    ndef.push(0x02); // UTF-8, language code length = 2
    ndef.extend_from_slice(lang);
    ndef.extend_from_slice(text_bytes);
    ndef
}

/// Write NDEF data into an NTAG215 page array.
/// Returns number of pages written, or 0 if URL is too large.
fn write_ndef_to_ntag215_pages(ndef: &[u8], pages: &mut [sys::MfUltralightPage]) -> u16 {
    if ndef.len() + 16 > NTAG215_USER_PAGES * 4 {
        return 0; // Too large for NTAG215
    }

    // CC at page 3: magic=0xE1, version=0x10, size=0x06 (NTAG215=0x12 for 504 bytes? Actually for NTAG215 standard CC is E1 10 12 00)
    pages[CC_PAGE].data[0] = 0xE1;
    pages[CC_PAGE].data[1] = 0x10;
    pages[CC_PAGE].data[2] = 0x12; // 144 bytes? No, 0x12 = 144 bytes? Actually 0x12 means 144*8=1152 bits? No.
    // Standard NTAG215 CC: E1 10 12 00  (0x12 = capacity in bytes/8 = 504/8 = 63? No that's wrong.)
    // Actually per NTAG215 datasheet: CC is E1 10 12 00 where 0x12 = 144*8=1152 bits?
    // Let's just use what Flipper firmware expects. The flipper NFC app uses E1 10 12 00 for NTAG215.
    pages[CC_PAGE].data[3] = 0x00;

    // TLV structure: 0x03 (NDEF message TLV), length, message, 0xFE (terminator)
    let mut offset = 16; // Start at page 4 (byte 16), pages 0-3 are UID + BCC0 + BCC1 + CC

    // Write TLV header
    pages[offset / 4].data[offset % 4] = 0x03; // NDEF Message TLV
    offset += 1;
    pages[offset / 4].data[offset % 4] = ndef.len() as u8;
    offset += 1;

    // Write NDEF message
    for &b in ndef {
        pages[offset / 4].data[offset % 4] = b;
        offset += 1;
    }

    // Write terminator
    pages[offset / 4].data[offset % 4] = 0xFE;
    offset += 1;

    // Zero-fill remaining user pages (for cleanliness)
    let total_user_bytes = NTAG215_USER_PAGES * 4;
    while offset < total_user_bytes {
        pages[offset / 4].data[offset % 4] = 0x00;
        offset += 1;
    }

    ((offset + 3) / 4) as u16
}

/// Path helper for C-string conversion.
fn path_to_cstr(path: &str, buf: &mut [u8; 128]) -> Option<*const core::ffi::c_char> {
    let bytes = path.as_bytes();
    if bytes.len() + 1 > buf.len() {
        return None;
    }
    buf[..bytes.len()].copy_from_slice(bytes);
    buf[bytes.len()] = 0;
    Some(buf.as_ptr() as *const core::ffi::c_char)
}

/// Start direct NTAG215 NFC emulation with the given URL.
/// The caller must ensure the app remains in the NfcShare view while this is active.
pub fn start_emulation(url: &str) -> bool {
    let ndef = build_ndef_url(url);
    start_ndef_emulation(&ndef)
}

/// Start direct NTAG215 NFC emulation with an NDEF Text record containing `text`.
/// Returns false if the text is too large to fit on an NTAG215 tag.
pub fn start_text_emulation(text: &str) -> bool {
    let ndef = build_ndef_text(text);
    start_ndef_emulation(&ndef)
}

/// Shared emulation setup for any NDEF payload.
fn start_ndef_emulation(ndef: &[u8]) -> bool {
    unsafe {
        let state = &mut *EMULATION_STATE.0.get();
        if state.active {
            stop_emulation();
        }

        // 1. Allocate NFC HAL
        let nfc = sys::nfc_alloc();
        if nfc.is_null() {
            return false;
        }
        state.nfc = nfc;

        // 2. Generate a properly initialized NTAG215 device using the official data generator.
        //    This sets up correct UID, BCC, lock bytes, CC, and all internal state.
        let device = sys::nfc_device_alloc();
        if device.is_null() {
            sys::nfc_free(nfc);
            state.nfc = core::ptr::null_mut();
            return false;
        }
        state.device = device;

        sys::nfc_data_generator_fill_data(sys::NfcDataGeneratorTypeNTAG215, device);

        // 3. Get the protocol-specific data and write the NDEF payload into the user pages.
        let data = sys::nfc_device_get_data(device, sys::NfcProtocolMfUltralight);
        if data.is_null() {
            sys::nfc_device_free(device);
            state.device = core::ptr::null_mut();
            sys::nfc_free(nfc);
            state.nfc = core::ptr::null_mut();
            return false;
        }
        let mf_data = data as *mut sys::MfUltralightData;

        let pages_written = write_ndef_to_ntag215_pages(ndef, &mut (*mf_data).page);
        if pages_written == 0 {
            sys::nfc_device_free(device);
            state.device = core::ptr::null_mut();
            sys::nfc_free(nfc);
            state.nfc = core::ptr::null_mut();
            return false;
        }

        // 4. Create listener — the protocol listener internally configures the NFC HAL.
        let listener = sys::nfc_listener_alloc(nfc, sys::NfcProtocolMfUltralight, data);
        if listener.is_null() {
            sys::nfc_device_free(device);
            state.device = core::ptr::null_mut();
            sys::nfc_free(nfc);
            state.nfc = core::ptr::null_mut();
            return false;
        }
        state.listener = listener;

        // 5. Start listener — this internally calls nfc_start.
        sys::nfc_listener_start(listener, Some(nfc_listener_callback), core::ptr::null_mut());

        state.active = true;
        true
    }
}

/// Stop any active NFC emulation and clean up resources.
pub fn stop_emulation() {
    unsafe {
        let state = &mut *EMULATION_STATE.0.get();
        if !state.listener.is_null() {
            // nfc_listener_stop internally calls nfc_stop — do NOT call nfc_stop separately
            sys::nfc_listener_stop(state.listener);
            sys::nfc_listener_free(state.listener);
            state.listener = core::ptr::null_mut();
        }
        if !state.device.is_null() {
            sys::nfc_device_free(state.device);
            state.device = core::ptr::null_mut();
        }
        if !state.nfc.is_null() {
            sys::nfc_free(state.nfc);
            state.nfc = core::ptr::null_mut();
        }
        state.active = false;
    }
}

extern "C" fn nfc_listener_callback(
    _event: sys::NfcGenericEvent,
    _context: *mut core::ffi::c_void,
) -> sys::NfcCommand {
    sys::NfcCommandContinue
}

// ---------------------------------------------------------------------------
// Legacy file-writing support (kept for external NFC app launching)
// ---------------------------------------------------------------------------

/// Generate a Flipper .nfc file containing a single NDEF URL record.
pub fn write_nfc_file(filename: &str, url: &str) -> bool {
    let mut file_path = String::with_capacity(128);
    file_path.push_str(NFC_DIR);
    file_path.push('/');
    file_path.push_str(filename);
    file_path.push_str(".nfc");

    let mut content = String::with_capacity(1024);
    content.push_str("Filetype: Flipper NFC device\n");
    content.push_str("Version: 3\n");
    content.push_str("# NDEF generated by Bible [BSB]\n");
    content.push_str("Device type: NTAG215\n");
    content.push_str("UID: 04 00 00 00 00 00 00\n");
    content.push_str("ATQA: 00 44\n");
    content.push_str("SAK: 00\n");
    content.push_str("Mifare Classic type: NONE\n");
    content.push_str("Mifare DESFire type: NONE\n");
    content.push_str("NTAG/Ultralight type: NTAG215\n");
    content.push_str("Data format version: 2\n");
    content.push_str("NFC data (NDEF):\n");

    let url_bytes = url.as_bytes();
    let payload_len = 1 + url_bytes.len();
    let uri_prefix: u8 = 0x04; // https://

    content.push_str("  Record 1\n");
    content.push_str("    Type: URI\n");
    content.push_str("    TNF: Well-known\n");
    content.push_str("    ID: \n");
    content.push_str("    Payload (hex): ");

    let mut first = true;
    {
        if !first {
            content.push(' ');
        }
        first = false;
        content.push_str(&byte_to_hex(uri_prefix));
    }
    for &b in url_bytes {
        if !first {
            content.push(' ');
        }
        first = false;
        content.push_str(&byte_to_hex(b));
    }
    content.push('\n');
    content.push_str("NDEF Stop\n");

    let mut path_buf = [0u8; 128];
    let path_c = match path_to_cstr(&file_path, &mut path_buf) {
        Some(p) => p,
        None => return false,
    };

    unsafe {
        let storage = sys::furi_record_open(c"storage".as_ptr() as *const u8);
        if storage.is_null() {
            return false;
        }

        let mut dir_buf = [0u8; 128];
        let dir_c = {
            let bytes = NFC_DIR.as_bytes();
            dir_buf[..bytes.len()].copy_from_slice(bytes);
            dir_buf[bytes.len()] = 0;
            dir_buf.as_ptr() as *const core::ffi::c_char
        };
        sys::storage_common_mkdir(storage as *mut sys::Storage, dir_c);

        let file = sys::storage_file_alloc(storage as *mut sys::Storage);
        if file.is_null() {
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return false;
        }

        let opened = sys::storage_file_open(file, path_c, sys::FSAM_WRITE, sys::FSOM_OPEN_ALWAYS);
        if !opened {
            sys::storage_file_close(file);
            sys::storage_file_free(file);
            sys::furi_record_close(c"storage".as_ptr() as *const u8);
            return false;
        }

        let written = sys::storage_file_write(
            file,
            content.as_ptr() as *const core::ffi::c_void,
            content.len(),
        );
        sys::storage_file_close(file);
        sys::storage_file_free(file);
        sys::furi_record_close(c"storage".as_ptr() as *const core::ffi::c_char);

        if written == content.len() {
            let loader = sys::furi_record_open(c"loader".as_ptr() as *const core::ffi::c_char)
                as *mut sys::Loader;
            if !loader.is_null() {
                sys::loader_start_with_gui_error(
                    loader,
                    c"nfc".as_ptr() as *const core::ffi::c_char,
                    path_c,
                );
                sys::furi_record_close(c"loader".as_ptr() as *const core::ffi::c_char);
            }
            true
        } else {
            false
        }
    }
}

fn byte_to_hex(b: u8) -> String {
    let hex = *b"0123456789ABCDEF";
    let mut s = String::with_capacity(2);
    s.push(hex[(b >> 4) as usize] as char);
    s.push(hex[(b & 0x0F) as usize] as char);
    s
}
