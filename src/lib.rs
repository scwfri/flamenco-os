#![feature(lang_items)]
#![no_std]
#![no_main]

mod vga_buffer;
extern crate rlibc;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn rust_main() {
    vga_buffer::test_print();

    loop {}
}

#[lang = "eh_personality"]
#[no_mangle]
pub extern "C" fn eh_personality() {}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
