# Version History

## v0.2.2 — CI test stage repair (Vitest 4 align + report robustness)

Four distinct bugs were causing the CI `test` stage to fail (and would have caused silent false-greens once tests landed):

- **`vite-plugin-glsl@1.6.0` × Vitest 2.1 incompatibility (root cause).** Under Vite 6.4 the plugin relies on Vite's declarative `transform.filter` hook-filter and drops its JS-level `createFilter` guard for Vite ≥6.3. Vitest 2.1.9's transform pipeline does not honor that declarative filter, so the shader transform ran on **every** file — rewriting each `.ts` test into `export default \`<source>\``, so Vitest collected **0 tests** (masked as a pass by `passWithNoTests: true`). Fix: bumped `vitest` + `@vitest/coverage-v8` `^2.1.0 → ^4.1.9` to align the runner with Vite 6 (Node-20 compatible per the v0.2.1 pin; vite `^6` in peer range). Verified: tests now collect with glsl active, and shader files import correctly as string defaults inside tests.
- **`pnpm test -- …` forwarded the literal `--`.** CI ran `vitest run -- --coverage --reporter=junit …`; the `--` turned every flag into a positional file-filter, so the junit reporter never activated and no report was written. Fix: added a dedicated `test:ci` script (`vitest run --coverage --reporter=default --reporter=junit --outputFile.junit=junit-test.xml`) and CI now calls `pnpm test:ci` — no arg-forwarding ambiguity.
- **`dorny/test-reporter@v1` default `fail-on-empty: true`** failed the job during the scaffold phase (zero committed test files → a valid but `tests="0"` report). Fix: set `fail-on-empty: false` so the empty scaffold-phase report surfaces as "0 tests" without failing; real failures still fail the job via Vitest's non-zero exit and dorny's `fail-on-error` (default true).
- **Node 20 deprecation** on the `dorny/test-reporter@v1` action runtime. Fix: bumped to `dorny/test-reporter@v3` (Node 24 runtime).

Also switched `vite.config.ts` to import `defineConfig` from `vitest/config` (type-safe with the `test` block) and renamed the report to `vitest tests`. Patch bump — CI/build toolchain only, no application runtime behavior change. (Remaining Node-20 deprecation warnings on `actions/checkout@v4` / `actions/setup-node@v4` / `actions/upload-artifact@v4` are non-failing and left as an optional follow-up.)

### Security documentation + Dockerfile lockfile integrity (same unreleased patch)

- **Security requirements documented.** New `<security>` section (7a) in `CLAUDE.md`/`AGENTS.md`: mandatory `sast` CI stage between `lint` and `test` (Semgrep + CodeQL SARIF + `pnpm audit --audit-level=high` + gitleaks; Trivy in `docker-build`), input-boundary inventory with injection class and defense per boundary, local-parity commands, and a Security check item in the completion checklist. Master plan gained a Security section (tool table + `lint → sast → test → build → docker-build` Mermaid diagram), a "CI + SAST Wiring" task, and two gate lines in every phase gate list (SAST green with zero HIGH/CRITICAL, MEDIUM triaged; new input boundaries injection-safe and documented).
- **CI provider references corrected.** `CLAUDE.md`/`AGENTS.md` section 7 heading, directory tree, and the Definition of Done named GitLab / `.gitlab-ci.yml`; the real pipeline has always been GitHub Actions (`.github/workflows/ci.yml` + `release.yml`). References now point at the real files. Both instruction files kept in sync.
- **`.codex/commands/pre-commit.md`:** added a SAST audit step (2a) and a SAST row in the verdict table.
- **`Dockerfile`:** `RUN pnpm install --frozen-lockfile || pnpm install` → `RUN pnpm install --frozen-lockfile`. The fallback silently resolved a stale lockfile with a fresh install, so the image could ship dependencies that differ from `pnpm-lock.yaml` (and from what CI tested). A lockfile mismatch now fails the build, matching CI.
- The wiring landed in the same unreleased patch — see the next subsection.

### Security wiring (same unreleased patch)

- **`sast` job added to `.github/workflows/ci.yml`** between `lint` and `test` (`needs: lint`): CodeQL (`javascript-typescript`, init → analyze), `semgrep scan` (`--config auto --config p/owasp-top-ten --config p/typescript --config p/react --config p/docker --severity ERROR --error`) with SARIF uploaded via `github/codeql-action/upload-sarif`, `gitleaks/gitleaks-action@v2`, and `pnpm audit --audit-level=high`. Job-level `permissions: security-events: write`. `test` now carries `needs: sast`, so a HIGH/CRITICAL finding blocks test → build → docker-build.
- **Trivy in `docker-build`:** the image is built with `load: true` and tagged `webgl-frontend:ci`, then scanned by `aquasecurity/trivy-action@0.28.0` (`severity: HIGH,CRITICAL`, `exit-code: 1`, `ignore-unfixed: true`).
- **`eslint.config.js`:** added `eslint-plugin-security` + `eslint-plugin-no-unsanitized` (recommended configs) so `eval`, `new Function`, raw `innerHTML`, and unsafe regex fail `lint`. `pnpm lint` passes with 0 errors (2 informational `detect-non-literal-fs-filename` warnings).
  > **Severity caveat (verified against the installed plugin):** every rule in `eslint-plugin-security`'s `recommended` config is `warn`, and this project's `lint` script is a bare `eslint .` with no `--max-warnings 0` — so those rules are *reported but cannot fail the build*. Only `eslint-plugin-no-unsanitized` (severity `error`, covering `innerHTML` / `outerHTML` / `insertAdjacentHTML` / `document.write`) actually gates today. Neither plugin covers `new Function` or the React `dangerouslySetInnerHTML` prop. To make the security rules gate, set them to `error` explicitly (and expect to triage `security/detect-object-injection`, which is noisy).
- **`nginx.conf`:** added `Content-Security-Policy` (`default-src 'self'`; `script-src 'self'`; `worker-src 'self' blob:`; `img-src 'self' data: blob:`; `object-src 'none'`; `frame-ancestors 'none'`; `style-src 'self' 'unsafe-inline'` documented as required by R3F/drei inline style attributes), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`.
  - **Correction (same version): the headers above were dropped on static assets.** nginx inherits `add_header` only when the current level declares none of its own, and the static-asset regex location declares its own `add_header Cache-Control`, which removed all four security headers from those responses. They are now repeated inside that block. `nginx -t` passes on the repaired config.
- **`package.json`:** added a `sast` script chaining Semgrep, gitleaks, and `pnpm audit` for local parity with the CI stage.
- Patch scope holds: CI, lint config, and static-serving headers only — no application runtime behavior change. Pending: `.semgrep/` rules directory.

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