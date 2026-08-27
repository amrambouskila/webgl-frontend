# Version History

## v0.2.2 — CI test stage repair (Vitest 4 align + report robustness)

### `docker-build` stage repair — two independent blockers (2026-08-28)

The `docker-build` job had been red since 2026-08-23 while `lint`, `sast`, `test` and `build` all
passed. It failed at **"Set up job"**, before a single step ran, which is why nothing downstream
was ever observed: neither `docker build` nor the Trivy scan had executed since the last green run
on 2026-06-25. Fixing the setup error exposed a second blocker underneath it.

- **`aquasecurity/trivy-action@0.28.0` no longer resolves** (`.github/workflows/ci.yml:119`).
  Run 33009843571 log: `##[error]Unable to resolve action aquasecurity/trivy-action@0.28.0, unable
  to find version 0.28.0`. **Root cause:** as part of the upstream response to the
  trivy-action supply-chain incident, the project migrated every tag to a `v` prefix and deleted
  the unprefixed ones -- `0.35.0` is the sole unprefixed tag left alive, deliberately kept to avoid
  breaking pinned workflows. `0.28.0` was not spared. GitHub resolves all of a job's actions during
  setup, so an unresolvable pin kills the job before checkout.
  **Fix:** pinned to `@v0.36.0`. All four inputs the workflow passes were diffed against `action.yaml`
  at both refs and are unchanged: `image-ref` (still honored by `entrypoint.sh` via `INPUT_IMAGE_REF`),
  `severity`, `exit-code`, `ignore-unfixed`. `cache` defaults to `true` at both refs, so caching
  behaviour did not change either.

- **`pnpm install --frozen-lockfile` fails inside the image** (`Dockerfile:8`) with
  `ERR_PNPM_LOCKFILE_CONFIG_MISMATCH  Cannot proceed with the frozen installation. The current
  "overrides" configuration doesn't match the value found in the lockfile`. **Root cause:** pnpm 10
  reads `overrides` from `pnpm-workspace.yaml`, not `package.json`, and `pnpm-lock.yaml` records the
  resolved set at its top. The build stage copied only `package.json` + `pnpm-lock.yaml`, so pnpm saw
  21 overrides in the lockfile and none in config, and `--frozen-lockfile` correctly refused. This
  landed with the 2026-08-24 dependency remediation that introduced `pnpm-workspace.yaml`, and stayed
  invisible because the trivy pin killed the job first.
  **Fix:** `COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./`. The `pnpm-lock.yaml*` glob was
  dropped at the same time -- all three files are tracked, and the glob would have silently degraded a
  missing lockfile into an unpinned install instead of failing loudly.

**Verified locally, not merely reasoned about:**

| Check | Result |
|-------|--------|
| `docker build -t webgl-frontend:ci-localtest .` | exit 0 (`tsc -b` + `vite build` clean, image exported) |
| `trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1` on that image | **0 vulnerabilities**, exit 0 (alpine 3.24.1, 71 packages) |
| `aquasecurity/trivy-action` tag `v0.36.0` | resolves; `0.28.0` returns HTTP 404 |

The Trivy result also retires an open question from the 2026-08-26 entry: the `apk upgrade --no-cache`
layer is now measured on the actual built image, not just the base, and it holds the gate at zero
HIGH/CRITICAL.

**Semver reasoning:** Patch. CI/build-infrastructure repair. No application code, dependency, host
port, API or data contract, and no test changed.


### Base-image security patch for the alpine runtime stage (2026-08-26)

- **`RUN apk upgrade --no-cache` added to `Dockerfile`.** The `nginx:alpine` base currently ships
  `libcrypto3`/`libssl3` 3.5.7-r0, which Trivy flags HIGH (`CVE-2026-14456`, an OpenSSL QUIC-server
  DoS, fixed in 3.5.8-r0). The packages come from the base layer, so nothing in the Dockerfile
  installs them and nothing below can remediate them -- the upgrade has to happen at build time.
  Measured directly against the base image: **2 HIGH before the layer, 0 after**.
- **Why this needed a change at all.** `nginx:alpine` measured clean during the 2026-08-24
  base-image sweep. The advisory landed afterwards. A base image being clean is a point-in-time
  observation, not a property, which is precisely why the patch layer belongs in the Dockerfile
  rather than being skipped on the strength of a past scan. This is the alpine counterpart to the
  `apt-get upgrade` layer the Debian bases already carry.
- **Superseded 2026-08-28.** This bullet claimed the pipeline has no `trivy image` step. That was
  wrong: `.github/workflows/ci.yml` has carried an `aquasecurity/trivy-action` step in `docker-build`
  all along. What was true is that it had never *executed* -- the job died at "Set up job" on an
  unresolvable action pin, so the scan was configured but never reached. The layer is therefore
  load-bearing, not merely preventive: see the docker-build repair entry below.

**Semver reasoning:** Patch. A build-time base-image security patch. No application code,
dependency, host port, API or data contract, and no test changed.


### CI hardening + dependency remediation (2026-08-24)

- **Semgrep invocation corrected.** The job used `semgrep ci` with `--severity` and `--error`, which that subcommand does not accept — it exits 2 with a usage error before scanning. Switched to `semgrep scan`, which supports both.
- **Release workflow hardened against script injection.** `${{ inputs.bump }}` and `${{ steps.bump.outputs.new_version }}` were interpolated directly into `run:` blocks, where the value becomes shell code. Both now pass through `env:` and are read as quoted shell variables. The input is `type: choice`, so this was not exploitable today — it is the pattern that breaks the moment the input type changes.
- **Security headers now actually delivered.** nginx inherits `add_header` from an enclosing level only when the current level declares none of its own, and the cache-control `location` blocks declared their own — silently dropping CSP, `nosniff`, `X-Frame-Options` and `Referrer-Policy` there. Because the SPA resolves through `try_files ... /index.html`, the document itself was served with **zero** security headers. Verified by serving the config in `nginx:alpine` and curling `/`: 0 headers before, 4 after. They are now repeated in each affected block, with a comment explaining why the duplication must stay.
- **Dockerfile `missing-user` suppressed with written justification**, per global CLAUDE.md section 9 (non-root is not required for personal local-dev containers). The nginx images additionally cannot run as non-root without the unprivileged image and a port change. Revisit before any deployment beyond localhost.
- **Dependency remediation via `pnpm-workspace.yaml`.** This project pins `pnpm@10.34.1`, and pnpm 10 writes `overrides` to `pnpm-workspace.yaml` rather than `package.json` — so the file is new here. 21 bounded overrides; audit clean and the build passes.

**On the override bounding.** `pnpm audit --fix` emits one override per advisory with an open-ended target, which lets the resolver jump majors — `>=3.2.6` pulled vitest 4.1.11 and broke its `@vitest/coverage-v8` peer. Each target is therefore capped at its own compatibility line (next major, or next minor for 0.x where semver treats the minor as breaking). The advisory-derived keys are kept verbatim rather than merged: esbuild had two disjoint ranges (`<=0.24.2` and `0.27.3-0.28.0`), and collapsing them to the highest target forced 0.28.2, which cannot lower destructuring to the configured browser targets.


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
- **Trivy in `docker-build`:** the image is built with `load: true` and tagged `webgl-frontend:ci`, then scanned by `aquasecurity/trivy-action@v0.36.0` (`severity: HIGH,CRITICAL`, `exit-code: 1`, `ignore-unfixed: true`).
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
