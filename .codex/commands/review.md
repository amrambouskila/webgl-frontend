---
name: review
description: Review changed code against project standards
---

# Code Review Command

Before anything else:
1. Re-read `AGENTS.md` in full.
2. Re-read `docs/WEBGL_FRONTEND_MASTER_PLAN.md`.

## Procedure

1. Run `git diff` to see all changed files.
2. Read every changed file **in full** (not just the diff).
3. Produce a checklist-style report with `file:line` references.

## Review Checklist

For each changed file, check:

### TypeScript Rules
- [ ] No `any` type
- [ ] No `@ts-ignore` without justification
- [ ] `const` by default, `let` only when reassignment needed
- [ ] `interface` preferred over `type` for object shapes
- [ ] Full type annotations on function signatures

### Shader Rules
- [ ] All GLSL in separate `.vert`/`.frag`/`.glsl` files
- [ ] No inline GLSL template strings in component files
- [ ] Shared noise/fresnel imported from `src/shaders/includes/`
- [ ] Every shader has `uTime`, `uMouse`, `uResolution` uniforms
- [ ] No built-in materials (MeshStandard, MeshPhong, etc.)

### Three.js / R3F Rules
- [ ] No raw imperative Three.js (always use R3F declarative components)
- [ ] No Three.js objects in Zustand state (geometries, materials, textures, meshes)
- [ ] All created resources disposed on unmount
- [ ] InstancedMesh used for >100 identical objects
- [ ] Only active/adjacent rooms update uniforms

### General Rules
- [ ] One concept per file
- [ ] No dead code, commented-out blocks, unused imports
- [ ] No magic numbers without named constants
- [ ] No duplicated logic (search for existing utils/hooks first)
- [ ] Names are precise and purpose-revealing

### Severity Levels
- **Critical** — Must fix before commit. Breaks architecture, introduces bugs, or violates non-negotiables.
- **Should-fix** — Important improvement. Technical debt if left.
- **Minor** — Style or preference. Fix if convenient.

## Output

Produce a verdict table: file, line, severity, issue, suggested fix. Do NOT automatically fix anything — report only.