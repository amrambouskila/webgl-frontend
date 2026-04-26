# AGENTS.md - WebGL Immersive Navigation Framework

---

> **MANDATORY WORKFLOW: READ THIS ENTIRE FILE BEFORE EVERY CHANGE.** Every time. No skimming, no assuming prior-session context carries over — it does not.
>
> **Why:** This project spans multiple sessions and months of development. Skipping the re-read produces decisions that contradict the architecture, duplicate existing patterns, break data contracts, or introduce tech debt that compounds.
>
> **The workflow, every time:**
> 1. Read this entire file in full.
> 2. Read the master plan document: `docs/WEBGL_FRONTEND_MASTER_PLAN.md`.
> 3. Read `docs/status.md` — current state / what was just built.
> 4. Read `docs/versions.md` — recent version history.
> 5. Read the source files you plan to modify — understand existing patterns first.
> 6. Then implement, following the rules and contracts defined here.

---

## 0. CRITICAL CONTEXT — THIS IS AN IMMERSIVE WEBGL FRAMEWORK

**READ THIS FIRST.** This is NOT "sprinkle WebGL onto a webpage." This is "the webpage lives inside a WebGL world." The entire site is an immersive 3D experience where users navigate between rooms (3D scenes) with custom GLSL shaders, scroll-driven camera animation, and post-processing effects. Inspired by Active Theory's approach.

### What This IS

- A full-viewport WebGL canvas at z-index 0 that IS the site
- DOM/HTML UI floats above the canvas as an overlay (z-index 10+)
- Each "page" or content section is a 3D room with its own shader aesthetic
- Navigation between rooms is via scroll, click, or keyboard with smooth camera transitions
- Every surface uses custom ShaderMaterial — NO built-in materials (MeshStandardMaterial, MeshPhongMaterial, etc.)
- Post-processing (bloom, chromatic aberration, vignette) is mandatory, not optional

### What This Is NOT

- Not a traditional React SPA with a Three.js widget embedded somewhere
- Not a product/dashboard with a decorative 3D background
- Not a portfolio template with a spinning 3D model
- MeshStandardMaterial is banned — every surface is a custom shader

### Current Phase

**Phase 1: Core Framework + 3 Rooms.** Build the rendering pipeline, camera system, scroll navigation, post-processing, and three distinct rooms with unique shader aesthetics.

---

## 1. Project Identity

- **Project:** `webgl-frontend` — WebGL immersive navigation framework
- **Location:** `webgl-frontend/`
- **Master Plan:** `docs/WEBGL_FRONTEND_MASTER_PLAN.md`
- **Design Spec:** `webgl-immersive-integration-prompt.md` (900-line architectural reference)
- **Phase:** 1 of 3

### Phase Roadmap

| Phase | What | Timeline |
|-------|------|----------|
| **1 (CURRENT)** | Core framework: renderer, camera, scroll nav, post-processing, 3 rooms (Nebula, Grid, Crystal) | Weeks 1-3 |
| 2 | Content integration: DOM overlay system, room-content mapping, loading states, accessibility | Weeks 3-5 |
| 3 | Performance optimization + mobile: device detection, LOD, reduced particles, touch nav, `prefers-reduced-motion` | Weeks 5-7 |

### Phase 1 Scope — Explicit Boundaries

**IN scope:**
- WebGL renderer setup (WebGL2, pixel ratio capping)
- Camera system with exponential lerp (frame-rate-independent damping)
- Scroll/keyboard/click navigation between rooms
- Post-processing pipeline (bloom, chromatic aberration, vignette)
- Three rooms: Nebula Field (particles), Grid Horizon (wireframe terrain), Crystal Lattice (instanced geometry)
- Shared GLSL noise library
- Navigation dots UI
- Zustand store for shared state (currentScene, scrollProgress, mouse, time, transitioning)
- Basic resize handling

**NOT in scope (Phase 2+):**
- DOM content overlay system
- Scene labels / HUD
- Loading screen / asset preloading
- Barba.js / page transitions
- Content-to-room mapping
- Accessibility (prefers-reduced-motion)
- Mobile-specific optimizations
- Draco/KTX2 asset compression
- Void Sphere room (Phase 2 — 4th room)

---

## 2. Architecture & Code Rules

### Separation of Concerns

The WebGL layer and the DOM layer are **separate concerns that share a coordinate system**:

- **WebGL layer (z-index: 0):** Full-viewport `<canvas>`, fixed position. Renders 3D rooms, camera, post-processing. Managed by R3F components.
- **DOM layer (z-index: 10+):** Navigation dots, labels, HUD, any HTML content. Floats above the canvas. `pointer-events: auto` only on interactive elements.
- **Shared state (Zustand):** `currentScene`, `scrollProgress`, `mouse`, `time`, `transitioning`. Both layers subscribe.

### React Three Fiber (R3F)

All Three.js code goes through `@react-three/fiber` and `@react-three/drei`. Never use raw imperative Three.js (`new THREE.Scene()`, `new THREE.WebGLRenderer()`, etc.) directly.

- R3F's `<Canvas>` component owns the renderer, scene, and render loop
- Each room is a declarative R3F component (`<NebulaRoom />`, `<GridRoom />`, `<CrystalRoom />`)
- Use `useFrame` for per-frame updates (uniform updates, camera lerp)
- Use `useThree` to access renderer, camera, scene when needed
- `<EffectComposer>` from `@react-three/postprocessing` for post-processing

### Custom Shaders — The Core Rule

**Every visible surface uses `ShaderMaterial` with hand-written GLSL.** This is the single most important aesthetic rule. `MeshStandardMaterial`, `MeshPhongMaterial`, and all built-in materials are banned.

- Shaders live in `src/shaders/` as separate `.vert` and `.frag` files
- Imported via `vite-plugin-glsl` (`import vertexShader from './shader.vert'`)
- Never inline GLSL as template strings in component files
- Shared GLSL utilities (noise, fresnel, smoothstep helpers) in `src/shaders/includes/`
- Every shader receives at minimum: `uTime`, `uMouse`, `uResolution`

### State Management

- **Zustand** for all shared state between WebGL and DOM layers
- **Never put Three.js objects in Zustand state** (geometries, materials, textures, meshes, cameras). These cause serialization issues and unnecessary re-renders. Use refs (`useRef`) for mutable Three.js objects.
- React `useState` only for UI-only concerns (panel open/closed, selected tab)
- Store shape:

```typescript
interface NavigationState {
  currentScene: number;
  targetScene: number;
  transitioning: boolean;
  sceneCount: number;
  goToScene: (index: number) => void;
}

interface InputState {
  mouse: { x: number; y: number };
  mouseTarget: { x: number; y: number };
  scrollProgress: number;
  time: number;
}
```

### Disposal Protocol

Three.js objects leak GPU memory if not disposed. Every component that creates geometries, materials, or textures **must dispose them on unmount**:

```typescript
useEffect(() => {
  return () => {
    geometry.dispose();
    material.dispose();
    texture?.dispose();
  };
}, []);
```

R3F handles basic disposal for declarative elements, but custom `ShaderMaterial` instances and programmatically created geometries need explicit cleanup.

### Room Architecture

Rooms are placed at fixed intervals along the Y axis in world space:

```
Room 0: position.y = 0
Room 1: position.y = -ROOM_SPACING
Room 2: position.y = -ROOM_SPACING * 2
Camera target for room N: y = -ROOM_SPACING * N
```

`ROOM_SPACING` = 30 units (large enough to prevent visual bleed between rooms).

Each room component:
- Is a `<group>` positioned at its Y offset
- Has its own meshes, shader materials, and optional lights
- Receives `active: boolean` prop — only update uniforms when active or adjacent
- Implements `onEnter()` / `onLeave()` lifecycle via effects
- Freezes uniforms when far from camera (performance)

### Camera System

The camera uses exponential lerp for smooth, weighted movement:

```typescript
const LERP_DECAY = 0.04; // Lower = slower/smoother
const lerpFactor = 1 - Math.pow(LERP_DECAY, delta);
position.lerp(target, lerpFactor);
```

This is frame-rate-independent damping. A flat lerp factor breaks at 30fps vs 144fps. **Never set camera position directly** — always set a target and let the lerp close the gap.

### File Organization

**One concept per file.** No god files.

- `src/components/three/NebulaRoom.tsx` — Nebula room and nothing else
- `src/hooks/useScrollNavigation.ts` — scroll navigation hook and nothing else
- `src/stores/navigationStore.ts` — navigation state and nothing else
- `src/types/RoomConfig.ts` — room config interface and nothing else
- `src/shaders/nebula.vert` — nebula vertex shader and nothing else

### TypeScript Rules

- `"strict": true` in tsconfig — no exceptions
- No `any` — no `@ts-ignore` without a comment and linked task
- `const` by default, `let` only when reassignment is necessary, never `var`
- Prefer `interface` over `type` for object shapes
- Full type annotations on every function, component prop, and hook return
- GLSL imports need a `src/types/glsl.d.ts` module declaration

### Naming Conventions

- **Components:** `PascalCase.tsx` (`NebulaRoom.tsx`, `NavigationDots.tsx`)
- **Hooks:** `useCamelCase.ts` (`useScrollNavigation.ts`, `useMouseTracking.ts`)
- **Stores:** `camelCaseStore.ts` (`navigationStore.ts`, `inputStore.ts`)
- **Types:** `PascalCase.ts` (`RoomConfig.ts`, `ShaderUniforms.ts`)
- **Shaders:** `camelCase.vert`, `camelCase.frag` (`nebula.vert`, `nebula.frag`)
- **Shader includes:** `camelCase.glsl` (`noise.glsl`, `fresnel.glsl`)

---

## 3. Performance Rules

### Targets

| Metric | Target |
|--------|--------|
| Frame rate | 60fps on mid-range GPU, 30fps minimum on mobile |
| LCP | < 2s |
| Total JS bundle | < 300KB gzipped (excluding three.js) |
| Draw calls per frame | < 20 |
| Particle count | 4000-8000 desktop, 1000-2000 mobile |

### Mandatory Optimizations

1. **Only update visible rooms.** Check `Math.abs(roomIndex - activeIndex) <= 1` before updating uniforms.
2. **InstancedMesh for >100 identical objects.** One draw call for hundreds of instances.
3. **LOD for >10k visible objects** (Phase 3, but design for it now).
4. **Cap pixel ratio:** `Math.min(window.devicePixelRatio, 2)`.
5. **BufferGeometry only** — never deprecated `Geometry`.
6. **Freeze distant room uniforms** — don't update `uTime`/`uMouse` on rooms 2+ away.
7. **Dispose on room transitions** — dispose geometries/materials when a room is far away.

---

## 4. Directory Structure

```
webgl-frontend/
├── AGENTS.md                          # This file
├── README.md                          # Human-facing overview
├── webgl-immersive-integration-prompt.md  # Design specification (reference)
├── docs/
│   ├── WEBGL_FRONTEND_MASTER_PLAN.md  # Authoritative master plan
│   ├── status.md                      # Current project state
│   └── versions.md                    # Semver changelog
├── .codex/
│   ├── settings.json                  # Hooks, permissions
│   ├── commands/                      # Slash commands
│   │   ├── scaffold.md
│   │   ├── review.md
│   │   ├── pre-commit.md
│   │   └── validate.md
│   └── skills/                        # Proactive protocol skills
│       ├── phase-awareness/
│       │   └── SKILL.md
│       └── frontend-protocol/
│           └── SKILL.md
├── src/
│   ├── App.tsx                        # Root: Canvas + DOM overlay wrapper
│   ├── main.tsx                       # Entry point
│   ├── components/
│   │   ├── ui/                        # DOM overlay components
│   │   │   └── NavigationDots.tsx     # Dot nav reflecting current scene
│   │   └── three/                     # R3F scene components
│   │       ├── Experience.tsx         # Scene orchestrator (rooms + camera + post-fx)
│   │       ├── CameraRig.tsx          # Lerp-based camera movement
│   │       ├── PostProcessing.tsx     # EffectComposer (bloom, chromatic, vignette)
│   │       ├── NebulaRoom.tsx         # Room 0: particle cloud
│   │       ├── GridRoom.tsx           # Room 1: wireframe terrain
│   │       └── CrystalRoom.tsx        # Room 2: instanced geometry
│   ├── hooks/
│   │   ├── useScrollNavigation.ts     # Wheel/touch/keyboard → scene index
│   │   └── useMouseTracking.ts        # Normalized mouse coords with lerp
│   ├── stores/
│   │   ├── navigationStore.ts         # Current scene, transitioning state
│   │   └── inputStore.ts             # Mouse, scroll progress, time
│   ├── shaders/
│   │   ├── includes/
│   │   │   └── noise.glsl            # Shared simplex noise (Ashima Arts)
│   │   ├── nebula.vert
│   │   ├── nebula.frag
│   │   ├── grid.vert
│   │   ├── grid.frag
│   │   ├── crystal.vert
│   │   ├── crystal.frag
│   │   ├── vignette.vert             # Post-processing vignette + chromatic
│   │   └── vignette.frag
│   ├── types/
│   │   ├── glsl.d.ts                 # Module declaration for .glsl/.vert/.frag imports
│   │   ├── RoomConfig.ts             # Room configuration interface
│   │   └── ShaderUniforms.ts         # Typed uniform interfaces
│   └── workers/                       # Web Workers (future — heavy compute offloading)
├── public/                            # Static assets
├── tests/
│   └── setup.ts                       # Vitest setup (cleanup)
├── index.html                         # Vite entry HTML
├── package.json
├── tsconfig.json
├── vite.config.ts
├── .gitignore
├── .gitlab-ci.yml
├── Dockerfile                         # Multi-stage: node build + nginx serve
├── docker-compose.yml
├── nginx.conf                         # Nginx config for SPA routing
├── run_webgl_frontend.sh
└── run_webgl_frontend.bat
```

---

## 5. Testing Requirements

- **Framework:** Vitest + React Testing Library
- **Coverage target:** 100% (global AGENTS.md contract)
- **Setup:** `tests/setup.ts` must import `cleanup` from `@testing-library/react` and call it in `afterEach`. Vitest does NOT auto-cleanup.
- **What to test:**
  - Store logic (navigation state transitions, input state updates)
  - Hook logic (scroll navigation index clamping, mouse normalization)
  - Utility functions (lerp, clamp, smoothstep JS helpers)
  - Component rendering (rooms mount without crashing, navigation dots reflect state)
- **What NOT to mock:** WebGL context, shader compilation, Three.js math. Test against real computations.
- **Numerical comparisons:** Use `expect(value).toBeCloseTo(expected, precision)` — never exact equality for floats.

---

## 6. Containerization

### Docker

- `Dockerfile` — Multi-stage: stage 1 (`node:20-alpine`) runs `pnpm install` + `pnpm build`; stage 2 (`nginx:alpine`) copies `dist/` and serves via `nginx.conf`.
- `docker-compose.yml` — Single service (`webgl-frontend`), exposes port via `${FRONTEND_PORT:-5173}`.
- `nginx.conf` — SPA routing: all routes fall through to `index.html`.
- No backend, no database, no healthcheck needed in Phase 1.

### Environment

```
FRONTEND_PORT=5173
```

---

## 7. CI/CD — GitLab

`.gitlab-ci.yml` pipeline stages:
1. **lint** — `pnpm lint`. Fail on errors.
2. **test** — `pnpm test -- --coverage`. Fail on test failure or coverage below threshold.
3. **build** — `pnpm build`. Must compile without errors.
4. **docker-build** — `docker build` to verify Dockerfile.

All MRs must pass CI before merging. Conventional commits for semver bumps.

---

## 8. Local Commands

**Without Docker:**
```bash
pnpm install          # Install dependencies
pnpm dev              # Dev server (Vite HMR)
pnpm lint             # ESLint
pnpm test             # Vitest (all tests)
pnpm test --coverage  # With coverage
pnpm build            # Production build
```

**With Docker:**
```bash
./run_webgl_frontend.sh        # macOS/Linux
run_webgl_frontend.bat         # Windows
```

---

## 9. Change Policy

1. **Before writing:** Re-read this file (mandatory).
2. **After changes:** Update `docs/status.md` and `docs/versions.md`.
3. **Version numbers:** Come from `package.json`. Compute next version per semver (see global AGENTS.md section 6). Do NOT modify `package.json` version directly.
4. **One unreleased version at a time** in `docs/versions.md`.

---

## 10. Phase 1 Completion Gate

Phase 1 is done when:

- [ ] Full-viewport canvas renders at 60fps on desktop
- [ ] Camera lerps between rooms with exponential damping (frame-rate independent)
- [ ] Scroll, keyboard (arrow keys, space), and click navigation work
- [ ] Navigation dots reflect current scene and allow click-to-jump
- [ ] Nebula Room: 4000+ particles, noise displacement, mouse repulsion, additive blending
- [ ] Grid Room: wireframe terrain, layered noise elevation, mouse ripple
- [ ] Crystal Room: 200+ instanced icosahedrons, per-instance rotation, fresnel glow
- [ ] Post-processing: bloom + chromatic aberration + vignette
- [ ] All shaders in separate .vert/.frag files (no inline GLSL strings)
- [ ] Zustand stores for navigation + input state
- [ ] Resize handling updates renderer, camera, and resolution uniforms
- [ ] No console errors or WebGL warnings
- [ ] Dockerfile builds, docker-compose starts, launcher scripts work
- [ ] GitLab CI pipeline passes (lint, test, build, docker)
- [ ] Tests cover store logic, hook logic, and utility functions
- [ ] `docs/status.md` and `docs/versions.md` current

---

## 11. Phase Transition Strategy

### Phase 1 → Phase 2 (Content Integration)

- Add DOM overlay system: scene labels, HUD, content panels
- Map existing content sections to rooms (title, subtitle, body become room metadata)
- Build loading screen with shader compilation progress
- Add 4th room (Void Sphere — displacement + glow ring)
- Add Barba.js or equivalent for multi-page transitions if needed
- GSAP ScrollTrigger for fine-grained scroll-to-animation sync

### Phase 2 → Phase 3 (Performance + Mobile)

- Device detection: GPU tier, screen size, touch capability
- Reduce particle counts on mobile (1000-2000)
- Simplify/disable post-processing on low-end devices
- Touch navigation (swipe between rooms)
- `prefers-reduced-motion`: disable particles, instant camera moves
- Draco mesh compression, KTX2 texture compression
- Lazy-load rooms not adjacent to current

---

## 12. Git — Hands Off

User manages all git operations. Read-only git commands (`git status`, `git diff`, `git log`) are fine for inspection. No `git add`, `git commit`, `git push`, or any state-mutating git command.

---

## 13. Output & Completion Expectations

When completing a task:
1. **Summary** — What changed and why (1-2 sentences).
2. **Reuse Check** — Searched for existing components/hooks/utils before writing new ones.
3. **Tech Debt Check** — No shortcuts, no `any`, no dead code, no inline GLSL.
4. **File Check** — One concept per file.
5. **Shader Check** — All GLSL in separate .vert/.frag/.glsl files. No inline strings.
6. **Disposal Check** — All created geometries/materials/textures disposed on unmount.
7. **Performance Check** — Only active/adjacent rooms update. InstancedMesh where applicable.
8. **Docs Check** — `status.md` and `versions.md` updated.
9. **Test Check** — Store/hook/utility logic has tests.
10. **Forward-Compatibility Check** — Room architecture supports Phase 2 content integration.
11. **Git State** — Report changed files, suggest commit message (do not commit).

---

## 14. Reminder: Read Before You Write

**Every session, every task — re-read this entire file first.** Then `docs/status.md` + `docs/versions.md`. Then source files you plan to touch. Only then implement. The design spec (`webgl-immersive-integration-prompt.md`) is the authoritative reference for shader techniques, room implementations, and architectural patterns.