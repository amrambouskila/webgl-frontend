---
name: frontend-protocol
description: Proactively applied when editing Three.js/R3F components, shaders, or stores; enforces disposal, instancing, LOD, no-objects-in-state, and shader file isolation
---

# Frontend Protocol Skill — Three.js / R3F / Shader Discipline

## When to Apply

- When editing any file in `src/components/three/`
- When editing any file in `src/shaders/`
- When editing any file in `src/stores/`
- When creating a new room, shader, or Three.js component

## Protocol Checks

### 1. Disposal Check

Every R3F component that creates GPU resources MUST dispose them on unmount.

**Must dispose:**
- `BufferGeometry` instances (`.dispose()`)
- `ShaderMaterial` instances (`.dispose()`)
- `Texture` instances (`.dispose()`)
- `InstancedBufferGeometry` instances (`.dispose()`)
- Any `RenderTarget` or `FrameBuffer` (`.dispose()`)

**Pattern:**
```typescript
useEffect(() => {
  // create resources
  return () => {
    geometry.dispose();
    material.dispose();
  };
}, []);
```

R3F handles disposal for declarative `<mesh>`, `<boxGeometry>`, etc. — but custom `ShaderMaterial` created via `useMemo` or `useRef` needs explicit cleanup.

### 2. No Three.js Objects in State

**NEVER store these in Zustand or React state:**
- `THREE.Geometry` / `THREE.BufferGeometry`
- `THREE.Material` / `THREE.ShaderMaterial`
- `THREE.Texture`
- `THREE.Mesh` / `THREE.Points` / `THREE.Group`
- `THREE.Camera`
- `THREE.Scene`

**Use `useRef` instead.** Three.js objects are mutable class instances — putting them in state causes serialization issues and unnecessary React re-renders.

**What CAN go in Zustand:** numbers, strings, booleans, plain objects, arrays of primitives. Scene index, mouse coordinates, transition flags — all fine.

### 3. Shader File Isolation

**All GLSL code lives in `src/shaders/` as separate files:**
- `.vert` for vertex shaders
- `.frag` for fragment shaders
- `.glsl` for shared includes (noise, fresnel, etc.)

**NEVER:**
- Inline GLSL as template string literals in `.tsx`/`.ts` files
- Copy-paste shared GLSL functions (noise, fresnel) — import from `includes/`
- Mix vertex and fragment shader code in one file

**Import pattern:**
```typescript
import vertexShader from '../shaders/nebula.vert';
import fragmentShader from '../shaders/nebula.frag';
```

### 4. Built-In Material Ban

**NEVER use:**
- `MeshStandardMaterial`
- `MeshPhongMaterial`
- `MeshLambertMaterial`
- `MeshBasicMaterial` (except for debugging, removed before commit)
- `MeshNormalMaterial`
- `MeshToonMaterial`

**ALWAYS use:** `ShaderMaterial` with custom GLSL vertex + fragment shaders.

This is the single most important aesthetic rule. Built-in materials produce the generic "looks like Three.js" appearance. Custom shaders are what create the Active Theory look.

### 5. Instancing for Repeated Geometry

When rendering more than ~100 identical objects:
- Use `THREE.InstancedMesh` or `THREE.InstancedBufferGeometry`
- Per-instance data (position, seed, color) via `InstancedBufferAttribute`
- One draw call for all instances

**NEVER:** Create separate `<mesh>` elements in a loop for identical geometry.

### 6. Active Room Updates Only

Room components receive an `active` boolean prop. The uniform update pattern:

```typescript
useFrame(({ clock }) => {
  if (!active && Math.abs(index - currentScene) > 1) return;
  // Update uniforms only for active + adjacent rooms
  material.uniforms.uTime.value = clock.getElapsedTime();
});
```

Distant rooms (2+ away from current) must NOT update uniforms — this wastes GPU cycles.

### 7. Performance Constants

- `ROOM_SPACING = 30` — units between rooms on Y axis
- `LERP_DECAY = 0.04` — camera lerp decay factor
- `MAX_PIXEL_RATIO = 2` — cap for `renderer.setPixelRatio`
- `PARTICLE_COUNT_DESKTOP = 6000` — nebula particles on desktop
- `INSTANCE_COUNT = 300` — crystal instances