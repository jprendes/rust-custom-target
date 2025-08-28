# Rust Custom Target

This is a minimal Rust project that demonstrates how to set up a custom target.
In this demo we create a target called `x86_64-custom-static` that's identical to `x86_64-unknown-none` but with a static relocation model.

## Getting Started

Simply run the following commands to get started:

```bash
just run
```

This will generate the custom target spec, build core, alloc and compiler-builtins for the custom target, and then build and run the project using the custom target.

## Manual steps

### 1. Get the target spec of a similar target

The custom target is based on the `x86_64-unknown-none` target provided by Rust.

We can get the target spec of this target with the `--print=target-spec-json` option.
However, this option is unstable, and we have two options to use it it:
1. Use a nightly `rustc`.
2. Use what the upstream Rust project uses, which is to set the `RUSTC_BOOTSTRAP=1` environment variable when invoking `cargo`.

We will use the second option.

```bash
env RUSTC_BOOTSTRAP=1 \
rustc -Zunstable-options --print=target-spec-json --target=x86_64-unknown-none > target/x86_64-custom-static.json
```

The content of the file reflects the configuration of the target in the [`TargetOptions`](https://doc.rust-lang.org/stable/nightly-rustc/rustc_target/spec/struct.TargetOptions.html) as a JSON file.

Modify the file to change the target's configuration. In this case, we specify the `relocation-model` to `static`.

```diff
 {
   ...,
   "supported-sanitizers": [...],
+  "relocation-model": "static",
   "target-pointer-width": "64"
 }
```

### 2. Build the standard library for the custom target

To build the standard library for the custom target, we create a dummy crate, in this case we can use the crate in the `hacks` directory.

Like with `--print=target-spec-json`, the `-Zbuild-std` options is unstable and we need to use the `RUSTC_BOOTSTRAP=1` environment variable to be able to build the standard library.

```bash
env RUSTC_BOOTSTRAP=1 \
cargo rustc \
    -Zbuild-std=core,alloc \
    -Zbuild-std-features=mem \
    --target=$PWD/target/x86_64-custom-static.json \
    --target-dir=$PWD/sysroot/target \
    --release \
    --manifest-path=$PWD/hacks/Cargo.toml
```

The `-Zbuild-std-features=mem` flag tells `cargo` to build the `compiler-builtins` crate with the `mem` feature enabled, which adds the intrinsics for memory operations like `memcpy`, `memset`, etc.

### 3. Creating a sysroot

To use the built standard library, we need to create a sysroot that contains the built libraries.
We can do this by copying the libraries from the `deps` directory from the target directory to the location where rustc expects to find them.

```bash
mkdir -p target/sysroot/lib/rustlib/x86_64-custom-static/lib
cp target/sysroot/target/x86_64-custom-static/release/deps/lib* \
   target/sysroot/lib/rustlib/x86_64-custom-static/lib/
```

### 4. Build and run the project

Now we can build and run the project using the custom target and the sysroot we just created.
Note that this does not require a nightly `cargo` or the `RUSTC_BOOTSTRAP` environment variable.

```bash
RUSTFLAGS="--sysroot=$PWD/target/sysroot" \
cargo run --target=$PWD/target/x86_64-custom-static.json --release
```