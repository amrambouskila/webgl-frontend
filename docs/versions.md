# Version History

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