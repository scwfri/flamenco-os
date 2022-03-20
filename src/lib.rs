#![feature(lang_items)]
#![no_std]
#![no_main]

mod vga_buffer;
extern crate rlibc;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn rust_main() {
    use core::fmt::Write;
    vga_buffer::WRITER.lock().write_str("hello again!").unwrap();

    write!(
        vga_buffer::WRITER.lock(),
        ", some numbers: {} | {}",
        42,
        1.335674
    )
    .unwrap();

    loop {}
}

#[lang = "eh_personality"]
#[no_mangle]
pub extern "C" fn eh_personality() {}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
