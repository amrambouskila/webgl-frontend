# Version History

## v0.2.1 — CI toolchain pin (pnpm)

- Pinned the package manager via `packageManager: "pnpm@10.34.1"` in package.json — corepack resolves an exact, Node-20-compatible pnpm; nothing floats.
- ci.yml, release.yml, Dockerfile: replaced `corepack prepare pnpm@latest --activate` with `corepack enable` (the version now comes from the packageManager field).
- Root cause: `pnpm@latest` floated to 11.5.2, which requires Node ≥22.13 (it imports `node:sqlite`) while CI and Docker pin Node 20 — pnpm crashed on load before install ran, failing every job. Patch bump: build/CI config only, no application behavior change.

## v0.1.1 — CI test stage unblock

- vite.config.ts: added `test.passWithNoTests: true` so the CI `test` stage exits 0 during scaffold phase (no test files yet). Flag is a no-op once test files land. Patch bump — config-only fix to unbreak the pipeline.

## v0.1.0 — Project Scaffold

- Full project directory structure created
- CLAUDE.md with architecture rules, phase constraints, performance targets, disposal protocol
- Master plan document with Mermaid diagrams (architecture, navigation flow, render pipeline, module deps, Gantt)
- README.md with project overview and architecture diagram
- Docker infrastructure: multi-stage Dockerfile (node build + nginx serve), docker-compose.yml, nginx.conf
- Launcher scripts: run_webgl_frontend.sh and run_webgl_frontend.bat with full [k]/[q]/[v]/[r] loop
- GitLab CI pipeline: lint, test, build, docker stages
- package.json with all Phase 1 dependencies (R3F, drei, postprocessing, GSAP, Lenis, Zustand, vite-plugin-glsl)
- TypeScript strict config, Vite config with GLSL plugin, ESLint config
- Vitest test setup with cleanup
- .claude/ hooks, commands (scaffold, review, pre-commit, validate), skills (phase-awareness, frontend-protocol)
- .gitignore with comprehensive exclusions