---
name: pre-commit
description: Read-only audit before the user commits — reports READY or NOT READY
---

# Pre-Commit Audit Command

Before anything else:
1. Re-read `AGENTS.md` in full.
2. Re-read `docs/WEBGL_FRONTEND_MASTER_PLAN.md`.

**This command NEVER stages or commits anything.** It only reports. The user runs git commands themselves.

## Audit Steps (run sequentially)

### 1. Lint Check
Run `pnpm lint` (or check if it would pass). Report errors.

### 2. Type Check
Run `pnpm tsc --noEmit`. Report type errors.

### 3. Test Check
Run `pnpm test`. Report failures and coverage.

### 4. Code Review
Run the `/review` checklist against all changed files. Report findings.

### 5. Shader Validation
For every `.vert`/`.frag`/`.glsl` file:
- Verify no inline GLSL strings exist in `.tsx`/`.ts` files
- Verify shared includes are used (not duplicated noise functions)
- Verify uniform declarations match TypeScript interfaces

### 6. Disposal Audit
For every Three.js component in `src/components/three/`:
- Verify all created geometries have `.dispose()` on unmount
- Verify all created materials have `.dispose()` on unmount
- Verify all created textures have `.dispose()` on unmount
- Verify no Three.js objects stored in Zustand state

### 7. Performance Audit
- Verify only active/adjacent rooms update uniforms
- Verify InstancedMesh used where >100 identical objects
- Verify pixel ratio capped at 2.0

### 8. Documentation Check
- `docs/status.md` reflects current state
- `docs/versions.md` has an entry for the current work
- Version number computed correctly (semver from package.json)

## Output

Produce a verdict table:

| Check | Status | Notes |
|-------|--------|-------|
| Lint | PASS/FAIL | ... |
| Types | PASS/FAIL | ... |
| Tests | PASS/FAIL | ... |
| Code Review | PASS/FAIL | ... |
| Shaders | PASS/FAIL | ... |
| Disposal | PASS/FAIL | ... |
| Performance | PASS/FAIL | ... |
| Docs | PASS/FAIL | ... |

**Final Verdict: READY TO COMMIT / NOT READY**

If NOT READY, list every blocking issue with file:line references.