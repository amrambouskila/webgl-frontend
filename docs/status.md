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