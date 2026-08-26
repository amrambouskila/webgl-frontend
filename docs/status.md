# Project Status

## Current Phase: 1 — Core Framework + 3 Rooms

## What Was Just Built

- Project scaffolded with full directory structure, configuration files, and documentation
- CLAUDE.md, README.md, master plan with Mermaid diagrams
- Docker infrastructure (Dockerfile, docker-compose.yml, nginx.conf, launcher scripts)
- GitHub Actions CI pipeline (.github/workflows/ci.yml + release.yml)
- package.json with all Phase 1 dependencies
- Vite + TypeScript + ESLint configuration
- Vitest test setup

## Current State

- **Infrastructure:** Complete (Docker, CI, config, docs)
- **Code:** Scaffold only — no implementation yet
- **Rooms:** 0 of 3 implemented
- **Post-processing:** Not yet implemented
- **Navigation:** Not yet implemented
- **Tests:** Setup only, no test files yet (vitest configured with `passWithNoTests: true` until first tests land). The test pipeline is now verified end-to-end (Vitest 4 + glsl active): test files collect, shader imports resolve to string defaults in tests, and a JUnit report is produced and surfaced via `dorny/test-reporter@v3`.

## Security

### Verified state (2026-08-26)

- **Alpine base-image CVEs patched at build time.** `CVE-2026-14456` (`libcrypto3`/`libssl3`
  3.5.7-r0, HIGH, fixed 3.5.8-r0) is cleared by an `apk upgrade` layer in the runtime stage --
  measured on the base image as 2 HIGH before, 0 after. The base scanned clean two days earlier,
  so the layer exists to stop a future advisory from becoming a pipeline failure.
- **No image scan runs in this repo's CI**, so nothing here was gating; the change is
  preventive and no per-image scan result is claimed.

### Verified state (2026-08-24)

- **Semgrep: clean.** Verified locally by running this repo's own CI command against the working tree (0 findings). The invocation itself was broken before today — `semgrep ci` rejects `--severity`/`--error` and exited 2 without scanning.
- **Dependency audit: clean.** Verified with the repo's own audit command and threshold, after the override/upgrade remediation; install and build re-verified in the CI image.
- **Security headers verified delivered** — confirmed by serving the config in `nginx:alpine` and inspecting the response for `/` (0 headers before the fix, 4 after).

- Not run locally: gitleaks and Trivy are not part of any project toolchain here; both were exercised through their official images during verification, and CI runs them on every pipeline.

**Wired.** The requirements in `CLAUDE.md`/`AGENTS.md` `<security>` (section 7a) and the master plan Security section are now enforced:

- `.github/workflows/ci.yml` has a `sast` job (`needs: lint`) running CodeQL `javascript-typescript`, `semgrep scan` with SARIF upload to Security → Code scanning, `gitleaks/gitleaks-action`, and `pnpm audit --audit-level=high`. `test` carries `needs: sast`, so a security finding blocks test → build → docker-build.
- `docker-build` builds with `load: true` as `webgl-frontend:ci` and runs `aquasecurity/trivy-action` (`severity: HIGH,CRITICAL`, `exit-code: 1`, `ignore-unfixed: true`).
- `eslint.config.js` extends `security.configs.recommended` + `noUnsanitized.configs.recommended` — `pnpm lint` passes (0 errors, 2 `detect-non-literal-fs-filename` warnings on the build-time config reader).
- `nginx.conf` sends `Content-Security-Policy` (`script-src 'self'`; `worker-src 'self' blob:` and `img-src … blob:` for the WebGL/worker paths; `style-src 'unsafe-inline'` only because R3F/drei set inline style attributes), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`.
- `package.json` has a `sast` script (`semgrep scan` + `gitleaks detect` + `pnpm audit`) for local parity.
- `Dockerfile` enforces `pnpm install --frozen-lockfile` (no fallback install).

Still pending: `.semgrep/` project rules directory (create it with the first repo-specific rule).

## What's Next

1. Zustand stores (navigationStore, inputStore)
2. R3F Canvas + Experience component
3. CameraRig with exponential lerp
4. Scroll navigation hook
5. Nebula Room (first room — particles + noise)
6. Post-processing pipeline
7. Grid Room + Crystal Room
8. Navigation dots UI
9. Tests for stores, hooks, utilities

## Recent Architectural Decisions

- Using @react-three/fiber (R3F) for declarative Three.js — all 3D through R3F, no imperative Three.js
- Zustand for shared state between WebGL and DOM layers
- vite-plugin-glsl for shader imports (separate .vert/.frag files, never inline)
- @react-three/postprocessing for post-processing (R3F-native EffectComposer)
- ROOM_SPACING = 30 units along Y axis between rooms
- Camera lerp decay factor = 0.04 (frame-rate independent exponential damping)
- Package manager pinned via `packageManager: pnpm@10.34.1`; CI/release/Dockerfile use `corepack enable` and inherit it (no more floating `pnpm@latest`, which had reached 11.5.2 and broke on the pinned Node 20)
- Test runner aligned to Vite 6: Vitest `2.1 → 4.1.9` (`vitest/config` defineConfig). Vitest 2.1 didn't honor Vite 6.4's declarative `transform.filter`, so `vite-plugin-glsl` mangled every `.ts` test file → 0 tests collected (a false green hidden by `passWithNoTests`). Vitest 4 fixes this and keeps glsl active in tests (shaders import as string defaults).
- CI test invocation moved from `pnpm test -- <flags>` (pnpm forwards the literal `--`, breaking flag parsing) to a dedicated `pnpm test:ci` script. `dorny/test-reporter` bumped `v1 → v3` (Node 24) with `fail-on-empty: false` for the scaffold phase (zero tests).