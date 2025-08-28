#![no_std]
#![no_main]

extern crate alloc;

use alloc::format;
use alloc::string::String;
use alloc::vec::Vec;

use buddy_system_allocator::LockedHeap;
use linux_syscall::{SYS_exit, SYS_exit_group, SYS_read, SYS_write, syscall};

#[global_allocator]
static HEAP_ALLOCATOR: LockedHeap<32> = LockedHeap::empty();
static mut HEAP: [u8; 1024 * 1024] = [0; 1024 * 1024]; // 1 MiB heap

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    write(format!("panic: {}\n", info.message()));
    exit(1);
}

fn exit(ec: i32) -> ! {
    let _ = unsafe { syscall!(SYS_exit_group, ec) };
    loop {
        let _ = unsafe { syscall!(SYS_exit, ec) };
    }
}

fn write(buf: impl AsRef<[u8]>) {
    let buf = buf.as_ref();
    let _ = unsafe { syscall!(SYS_write, 1, buf.as_ptr(), buf.len()) };
}

fn read() -> u8 {
    let buf = &mut [0u8; 1];
    let _ = unsafe { syscall!(SYS_read, 0, buf.as_mut_ptr(), buf.len()) };
    buf[0]
}

fn read_line() -> String {
    let mut line = Vec::new();
    loop {
        let c = read();
        if c == b'\n' || c == b'\r' || c == 0 {
            break;
        }
        line.push(c);
    }
    String::from_utf8_lossy(&line).into_owned()
}

#[unsafe(no_mangle)]
pub extern "C" fn _start() -> ! {
    unsafe {
        #[allow(static_mut_refs)]
        HEAP_ALLOCATOR
            .lock()
            .init(HEAP.as_mut_ptr() as _, HEAP.len());
    }

    write(b"Hello, what's your name?\n> ");

    let name = read_line();
    write(format!("Hello {name}!\n"));
    exit(0);
}
