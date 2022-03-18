#![feature(lang_items)]
#![no_std]
#![no_main]

extern crate rlibc;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn rust_main() {
    let hello = b"Hello World!";
    let color_byte = 0x1f;

    let mut hello_colored = [color_byte; 24];
    for (i, char_byte) in hello.into_iter().enumerate() {
        hello_colored[i * 2] = *char_byte;
    }

    let buffer_ptr = (0xb8000 + 1988) as *mut _;
    unsafe { *buffer_ptr = hello_colored };

    loop {}
}

#[lang = "eh_personality"]
#[no_mangle]
pub extern "C" fn eh_personality() {}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
