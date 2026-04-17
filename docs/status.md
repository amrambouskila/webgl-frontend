# Project Status

## Current Phase: 1 — Core Framework + 3 Rooms

## What Was Just Built

- Project scaffolded with full directory structure, configuration files, and documentation
- CLAUDE.md, README.md, master plan with Mermaid diagrams
- Docker infrastructure (Dockerfile, docker-compose.yml, nginx.conf, launcher scripts)
- GitLab CI pipeline (.gitlab-ci.yml)
- package.json with all Phase 1 dependencies
- Vite + TypeScript + ESLint configuration
- Vitest test setup

## Current State

- **Infrastructure:** Complete (Docker, CI, config, docs)
- **Code:** Scaffold only — no implementation yet
- **Rooms:** 0 of 3 implemented
- **Post-processing:** Not yet implemented
- **Navigation:** Not yet implemented
- **Tests:** Setup only, no test files yet (vitest configured with `passWithNoTests: true` until first tests land)

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