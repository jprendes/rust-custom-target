PWD := justfile_dir()
TRIPLET := "x86_64-custom-static"
BASE_TRIPLET := "x86_64-unknown-none"
TARGET_SPEC := PWD + "/target/" + TRIPLET + ".json"
BASE_TARGET_SPEC := PWD + "/target/" + BASE_TRIPLET + ".json"
SYSROOT_DIR := PWD + "/target/sysroot"

default: run

# Download the Rust std source code if not already available
get-rust-src:
    rustup component add rust-src

# Make a custom target just like x86_64-unknown-none but with static relocation model
generate-target-spec:
    @mkdir -p {{SYSROOT_DIR}}
    RUSTC_BOOTSTRAP=1 rustc \
        -Z unstable-options \
        --target {{BASE_TRIPLET}} \
        --print target-spec-json \
        > {{BASE_TARGET_SPEC}}
    cat {{BASE_TARGET_SPEC}} \
        | jq '.["relocation-model"] = "static"' \
        > {{TARGET_SPEC}}

# Generate the sysroot for the custom target
make-sysroot: generate-target-spec get-rust-src
    @mkdir -p {{SYSROOT_DIR}}
    env RUSTC_BOOTSTRAP=1 \
        cargo rustc \
            -Zbuild-std=core,alloc \
            -Zbuild-std-features=mem \
            --target {{TARGET_SPEC}} \
            --release \
            --target-dir {{SYSROOT_DIR}}/target \
            --manifest-path {{PWD}}/hacks/Cargo.toml
    @mkdir -p {{SYSROOT_DIR}}/lib/rustlib/{{TRIPLET}}/lib
    cp {{SYSROOT_DIR}}/target/{{TRIPLET}}/release/deps/lib* \
       {{SYSROOT_DIR}}/lib/rustlib/{{TRIPLET}}/lib/

build: make-sysroot
    RUSTFLAGS="--sysroot={{SYSROOT_DIR}}" \
    cargo build \
        --target {{TARGET_SPEC}} \
        --release

run: make-sysroot
    RUSTFLAGS="--sysroot={{SYSROOT_DIR}}" \
    cargo run \
        --target {{TARGET_SPEC}} \
        --release
