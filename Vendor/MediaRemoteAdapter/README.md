# mediaremote-adapter (vendored)

[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) by Jonas van den Berg, BSD 3-Clause (see `LICENSE`).

- Tag `v0.7.7`, commit `e3ff5021eb0875858bd05f48d2e9ba2e962d1cf6`.
- Vendored: `bin/mediaremote-adapter.pl`, `include/`, `src/`, `LICENSE`. Upstream's CMake files, scripts and README are not included.

## Why

From macOS 15.4 a third-party app can no longer read system Now Playing through the private MediaRemote framework. The adapter loads a small framework into `/usr/bin/perl`, which macOS still allows, and prints Now Playing as JSON lines. Scrobble Now uses it only when "Detect any player (experimental)" is on in Settings.

## Build

`build.sh FRAMEWORKS_DIR EXECUTABLES_DIR` compiles `MediaRemoteAdapter.framework` and `MediaRemoteAdapterTestClient` with `xcrun clang` (no CMake) and signs both ad hoc. The ScrobbleNow target runs it as the "Build MediaRemoteAdapter" script phase, into `Contents/Frameworks` and `Contents/MacOS`; the script goes to `Contents/Resources`. It skips the build when nothing in `src/` or `include/` is newer than the built framework. The release workflow re-signs every Mach-O with the Developer ID and hardened runtime.

## Updating

Replace `bin/`, `include/`, `src/` and `LICENSE` from the new tag, update the tag and commit above, and check `src/adapter/*.m` against the source list in `build.sh`.
