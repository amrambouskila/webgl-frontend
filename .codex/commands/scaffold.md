---
name: scaffold
description: Scaffold a new module or component following project conventions
---

# Scaffold Command

Before anything else:
1. Re-read `AGENTS.md` in full.
2. Re-read `docs/WEBGL_FRONTEND_MASTER_PLAN.md`.
3. Confirm the scaffolding scope with the user.

## What This Command Does

Generates the directory structure and empty-signature files for a new module. Does NOT implement logic — only creates files with:
- TypeScript type annotations
- Function/component signatures
- Prop interfaces
- Import statements
- GLSL file stubs (for shader modules)

## Scaffolding Rules

1. **One concept per file.** Every component, hook, store, type, and shader gets its own file.
2. **Shader files are separate.** `.vert` and `.frag` files in `src/shaders/`, never inline strings.
3. **Follow naming conventions:**
   - Components: `PascalCase.tsx`
   - Hooks: `useCamelCase.ts`
   - Stores: `camelCaseStore.ts`
   - Types: `PascalCase.ts`
   - Shaders: `camelCase.vert`, `camelCase.frag`
4. **Room components** go in `src/components/three/`.
5. **DOM overlay components** go in `src/components/ui/`.
6. **Every room** must implement the `RoomProps` interface (`index`, `active`, `spacing`).
7. **Every shader** must declare at minimum: `uTime`, `uMouse`, `uResolution` uniforms.

## For a New Room

Create:
- `src/components/three/<RoomName>Room.tsx` — R3F component with RoomProps
- `src/shaders/<roomName>.vert` — vertex shader stub
- `src/shaders/<roomName>.frag` — fragment shader stub
- `tests/<roomName>Room.test.tsx` — test file stub

## For a New Hook

Create:
- `src/hooks/use<HookName>.ts` — hook with typed return value
- `tests/use<HookName>.test.ts` — test file stub

## For a New Store

Create:
- `src/stores/<storeName>Store.ts` — Zustand store with typed state interface
- `tests/<storeName>Store.test.ts` — test file stub

## Output

Report the full list of created files and wait for the user to review before any implementation begins.