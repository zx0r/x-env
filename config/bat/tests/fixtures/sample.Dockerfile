# Environment X Syntax Test Fixture: Dockerfile
ARG RUST_VERSION=1.85.0
FROM rust:${RUST_VERSION}-slim AS builder

WORKDIR /usr/src/app
ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse \
    RUSTFLAGS="-C target-cpu=native"

COPY Cargo.toml Cargo.lock ./
COPY src ./src

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev && \
    cargo build --release && \
    strip target/release/app

FROM debian:bookworm-slim AS runner
WORKDIR /app
COPY --from=builder /usr/src/app/target/release/app /usr/local/bin/app

USER 10001:10001
EXPOSE 8080 9090
ENTRYPOINT ["/usr/local/bin/app"]
CMD ["--config", "/etc/app/config.toml"]
