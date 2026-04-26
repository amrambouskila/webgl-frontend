---
name: phase-awareness
description: Proactively applied at session start and before any implementation work; orients Codex to the current phase and its explicit scope constraints
---

# Phase Awareness Skill

## When to Apply

- At the start of every session
- Before implementing any new feature or component
- When the user asks about scope or "should we add X?"

## Protocol

### 1. Identify Current Phase

Read `docs/status.md` to determine the current phase. As of project creation:

**Phase 1: Core Framework + 3 Rooms**

### 2. Enforce Phase Boundaries

#### Phase 1 — IN Scope
- WebGL renderer setup (R3F Canvas, WebGL2, pixel ratio capping)
- Camera system with exponential lerp
- Scroll/keyboard/click navigation between rooms
- Post-processing pipeline (bloom, chromatic aberration, vignette)
- Three rooms: Nebula Field, Grid Horizon, Crystal Lattice
- Shared GLSL noise library
- Navigation dots UI
- Zustand stores (navigation, input)
- Resize handling
- Tests for stores, hooks, utilities

#### Phase 1 — OUT of Scope (Do NOT implement)
- DOM content overlay system (Phase 2)
- Scene labels / HUD (Phase 2)
- Loading screen / asset preloading (Phase 2)
- Barba.js / page transitions (Phase 2)
- Content-to-room mapping (Phase 2)
- Void Sphere room (Phase 2)
- GSAP ScrollTrigger continuous scroll (Phase 2)
- `prefers-reduced-motion` (Phase 3)
- Mobile-specific optimizations (Phase 3)
- Device detection / GPU tier (Phase 3)
- Draco/KTX2 asset compression (Phase 3)
- Touch navigation refinement (Phase 3)

### 3. Flag Scope Violations

If the user requests something out of scope for the current phase:
1. Identify which phase it belongs to
2. Explain why it's deferred (what prerequisite work is needed first)
3. Ask if they want to proceed anyway or defer

### 4. Forward-Compatibility Check

Before implementing anything in Phase 1, verify it doesn't block Phase 2/3:
- Room components must accept content props (even if unused now)
- Shader uniforms must include `uProgress` for future transitions
- Navigation store must support arbitrary scene counts
- DOM overlay z-index convention must be established now