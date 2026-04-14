# WebGL Immersive Navigation — Integration Spec & Agent Prompt

> **Purpose**: This document is a self-contained prompt for an AI coding agent. It describes the architecture, techniques, and implementation patterns needed to transform an existing frontend into an immersive, WebGL-powered site with full 3D scene navigation, custom shaders, scroll-driven camera animation, and post-processing — inspired by the approach used at Active Theory (activetheory.net).
>
> **How to use**: Paste this entire document as context into a conversation with an AI coding agent alongside your existing codebase. The agent should treat this as the authoritative architectural spec for the refactor.

---

## 1. ARCHITECTURAL OVERVIEW

The goal is a site where the user navigates between immersive 3D "rooms" or scenes. Each room is a distinct visual environment with its own shader aesthetic, geometry, and interactivity. A WebGL canvas covers the full viewport behind all HTML/CSS UI. Navigation between rooms is driven by scroll, click, or keyboard, with smooth camera transitions. HTML UI elements (navigation, text, labels) float above the canvas as an overlay.

### Core architectural principle

**The WebGL layer and the DOM layer are separate concerns that share a coordinate system.** The canvas renders the 3D world. The DOM renders text, navigation, and interactive UI. They are synchronized through a shared state object. This is not a "sprinkle WebGL onto a webpage" approach — it is a "the webpage lives inside a WebGL world" approach.

### System diagram

```
┌─────────────────────────────────────────────┐
│                  Browser                     │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │          DOM Overlay (z-index: 10)    │   │
│  │   Nav / Labels / HUD / Transitions   │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │     WebGL Canvas (z-index: 0)         │   │
│  │                                       │   │
│  │  ┌─────────┐ ┌─────────┐ ┌────────┐ │   │
│  │  │ Room 0  │ │ Room 1  │ │ Room 2 │ │   │
│  │  │ y=0     │ │ y=-30   │ │ y=-60  │ │   │
│  │  └─────────┘ └─────────┘ └────────┘ │   │
│  │                                       │   │
│  │  Camera ──lerp──▶ target position     │   │
│  │  PostFX: bloom / chromatic / vignette │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │          Shared State                 │   │
│  │   currentScene, scrollProgress,       │   │
│  │   mouse, time, transitioning          │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

### Scene layout in world space

Rooms are placed at fixed intervals along one axis (typically Y or Z). The camera moves between them. Each room is a `THREE.Group` containing its own meshes, lights, and shaders. Rooms that are far from the camera can have their uniforms frozen (or meshes set to `visible = false`) for performance.

```
Room 0:  position.y = 0
Room 1:  position.y = -SPACING
Room 2:  position.y = -SPACING * 2
...
Camera target for room N:  y = -SPACING * N
```

`SPACING` should be large enough (20–40 units) that adjacent rooms don't visually bleed into each other, unless intentional.

---

## 2. TECHNOLOGY STACK

### Required

| Layer | Technology | Why |
|-------|-----------|-----|
| 3D engine | **Three.js** (r150+) | Industry standard. Active Theory outgrew it and built Hydra, but three.js is the right starting point. Use `WebGLRenderer` with WebGL2. |
| Shaders | **Custom GLSL via `ShaderMaterial`** | This is non-negotiable for the Active Theory look. `MeshStandardMaterial` and built-in materials will never produce that aesthetic. Every surface must be a custom shader. |
| Animation | **GSAP** (GreenSock) | For camera transitions, UI animation, and timeline control. The `ScrollTrigger` plugin syncs scroll position to animation progress. |
| Scroll | **Lenis** or custom scroll normalization | Smooth, momentum-based scroll that works cross-platform. Maps wheel/touch input to a normalized 0–1 progress value. |
| Post-processing | **Three.js EffectComposer** or custom render-target pipeline | Bloom, chromatic aberration, vignette, and transition effects via multi-pass rendering. |

### Recommended

| Layer | Technology | Why |
|-------|-----------|-----|
| Build tool | **Vite** | Fast HMR, native ES modules, GLSL import via `vite-plugin-glsl`. |
| GLSL management | **vite-plugin-glsl** | `import shader from './shader.glsl'` — keeps shaders in separate files instead of template strings. |
| State management | Plain JS module or Zustand | A reactive store that both the WebGL loop and DOM components can subscribe to. |
| Asset compression | **Draco** (for meshes), **Basis/KTX2** (for textures) | Active Theory achieves ~1.3s LCP on desktop through aggressive compression. |
| Page transitions | **Barba.js** or **Swup** | If the site is multi-page, these handle smooth transitions without full reloads. |

---

## 3. FILE STRUCTURE

```
src/
├── index.html
├── main.js                    # Entry point: init renderer, start loop
├── state.js                   # Shared reactive state
│
├── gl/                        # Everything WebGL
│   ├── Renderer.js            # THREE.WebGLRenderer setup, resize handling
│   ├── Camera.js              # PerspectiveCamera, lerp-based movement
│   ├── SceneManager.js        # Creates/manages rooms, handles transitions
│   ├── PostProcessing.js      # EffectComposer, bloom, chromatic, vignette
│   │
│   ├── rooms/                 # One module per room/scene
│   │   ├── BaseRoom.js        # Abstract base class for all rooms
│   │   ├── Room0_Nebula.js    # Particle cloud room
│   │   ├── Room1_Grid.js      # Wireframe terrain room
│   │   ├── Room2_Crystal.js   # Instanced geometry room
│   │   └── Room3_Void.js      # Raymarched sphere room
│   │
│   └── shaders/               # GLSL files
│       ├── noise.glsl         # Shared simplex/perlin noise functions
│       ├── nebula.vert
│       ├── nebula.frag
│       ├── grid.vert
│       ├── grid.frag
│       ├── bloom.frag         # Post-processing shaders
│       └── composite.frag
│
├── ui/                        # DOM layer
│   ├── Navigation.js          # Dot nav, keyboard nav
│   ├── SceneLabel.js          # Title/subtitle that updates per room
│   ├── HUD.js                 # FPS counter, scene counter
│   └── Transitions.js         # CSS/GSAP overlay transitions
│
├── scroll/                    # Scroll management
│   └── ScrollManager.js       # Lenis or custom, emits normalized progress
│
└── utils/
    ├── math.js                # lerp, clamp, map, smoothstep in JS
    └── resizeObserver.js      # Centralized resize handling
```

---

## 4. CORE IMPLEMENTATION PATTERNS

### 4.1 The Render Loop

One `requestAnimationFrame` loop drives everything. No separate loops for UI vs GL.

```javascript
// main.js
import { state } from './state.js';
import { renderer } from './gl/Renderer.js';
import { camera } from './gl/Camera.js';
import { sceneManager } from './gl/SceneManager.js';
import { postProcessing } from './gl/PostProcessing.js';
import { scrollManager } from './scroll/ScrollManager.js';

const clock = new THREE.Clock();

function loop() {
  requestAnimationFrame(loop);

  const dt = clock.getDelta();
  const elapsed = clock.getElapsedTime();

  // 1. Update inputs
  scrollManager.update();
  state.time = elapsed;

  // 2. Update mouse (lerp toward target for smoothness)
  state.mouse.x += (state.mouseTarget.x - state.mouse.x) * 0.05;
  state.mouse.y += (state.mouseTarget.y - state.mouse.y) * 0.05;

  // 3. Update camera position (lerp toward target room)
  camera.update(dt);

  // 4. Update active room shaders (pass time, mouse as uniforms)
  sceneManager.update(elapsed, state.mouse);

  // 5. Render with post-processing
  postProcessing.render(sceneManager.scene, camera.instance);
}

loop();
```

### 4.2 Camera System

The camera lerps toward a target position. This creates the smooth, weighted movement that defines the Active Theory feel. Never set camera position directly — always set a target and let the lerp close the gap.

```javascript
// gl/Camera.js
export class Camera {
  constructor() {
    this.instance = new THREE.PerspectiveCamera(60, w/h, 0.1, 500);
    this.instance.position.set(0, 0, 8);
    this.target = new THREE.Vector3(0, 0, 8);
    this.lookTarget = new THREE.Vector3(0, 0, 0);
    this.lookCurrent = new THREE.Vector3(0, 0, 0);
  }

  setRoom(index, spacing) {
    // Set the target — the lerp in update() will move us there
    this.target.y = -index * spacing;
    this.lookTarget.y = -index * spacing;
  }

  update(dt) {
    // Exponential lerp: fast start, slow finish
    // The 0.04 factor controls transition speed (lower = slower/smoother)
    const lerpFactor = 1 - Math.pow(0.04, dt);

    this.instance.position.x += (this.target.x - this.instance.position.x) * lerpFactor;
    this.instance.position.y += (this.target.y - this.instance.position.y) * lerpFactor;
    this.instance.position.z += (this.target.z - this.instance.position.z) * lerpFactor;

    this.lookCurrent.lerp(this.lookTarget, lerpFactor);
    this.instance.lookAt(this.lookCurrent);
  }
}
```

**Why `1 - Math.pow(0.04, dt)` instead of a flat lerp factor?**
Frame-rate-independent damping. A flat `0.05` lerp breaks at 30fps vs 144fps. The exponential form gives identical visual motion at any framerate. `0.04` means roughly 4% of the remaining distance is covered per second — adjust to taste.

### 4.3 Scroll Management

Scroll input is normalized to discrete scene indices. Continuous scroll within a scene can drive shader uniforms.

```javascript
// scroll/ScrollManager.js
export class ScrollManager {
  constructor(sceneCount, onSceneChange) {
    this.sceneCount = sceneCount;
    this.currentScene = 0;
    this.onSceneChange = onSceneChange;
    this.cooldown = false;

    window.addEventListener('wheel', this.onWheel.bind(this), { passive: false });
    window.addEventListener('keydown', this.onKey.bind(this));

    // Touch support
    this.touchStartY = 0;
    window.addEventListener('touchstart', e => { this.touchStartY = e.touches[0].clientY; });
    window.addEventListener('touchend', e => {
      const delta = this.touchStartY - e.changedTouches[0].clientY;
      if (Math.abs(delta) > 50) this.navigate(delta > 0 ? 1 : -1);
    });
  }

  onWheel(e) {
    e.preventDefault();
    if (this.cooldown) return;
    const direction = Math.sign(e.deltaY);
    this.navigate(direction);
  }

  onKey(e) {
    if (e.key === 'ArrowDown' || e.key === ' ') this.navigate(1);
    if (e.key === 'ArrowUp') this.navigate(-1);
  }

  navigate(direction) {
    const next = this.currentScene + direction;
    if (next < 0 || next >= this.sceneCount) return;

    this.currentScene = next;
    this.cooldown = true;
    this.onSceneChange(this.currentScene);

    // Cooldown prevents rapid-fire scene changes
    setTimeout(() => { this.cooldown = false; }, 1200);
  }
}
```

### 4.4 Room Base Class

Every room extends a base class that standardizes the interface.

```javascript
// gl/rooms/BaseRoom.js
export class BaseRoom {
  constructor(index, spacing) {
    this.group = new THREE.Group();
    this.group.position.y = -index * spacing;
    this.materials = []; // Track all ShaderMaterials for uniform updates
    this.index = index;
  }

  // Called every frame for the active room (and adjacent rooms)
  update(time, mouse) {
    for (const mat of this.materials) {
      if (mat.uniforms.uTime) mat.uniforms.uTime.value = time;
      if (mat.uniforms.uMouse) mat.uniforms.uMouse.value.copy(mouse);
    }
  }

  // Called when this room becomes active
  onEnter() {}

  // Called when the camera leaves this room
  onLeave() {}

  // Cleanup
  dispose() {
    this.group.traverse(child => {
      if (child.geometry) child.geometry.dispose();
      if (child.material) child.material.dispose();
    });
  }
}
```

### 4.5 Custom Shaders — The Core Technique

**This is what separates an Active Theory-grade site from a generic three.js site.** Every visible surface uses `ShaderMaterial` with hand-written GLSL. No `MeshStandardMaterial`, no `MeshPhongMaterial`, no built-in lighting.

#### Why custom shaders?

1. **Total pixel control** — you decide exactly what every pixel looks like.
2. **Performance** — the GPU only runs the code you write. No unused lighting calculations.
3. **Unique aesthetic** — built-in materials all look the same. Custom shaders look like nothing else.
4. **Reactivity** — uniforms let you pipe in mouse position, time, scroll progress, audio, or any other signal directly to the GPU.

#### Anatomy of a ShaderMaterial

```javascript
const material = new THREE.ShaderMaterial({
  // Render settings
  transparent: true,
  depthWrite: false,              // For additive/transparent effects
  blending: THREE.AdditiveBlending, // Glow effect: colors ADD instead of replace
  side: THREE.DoubleSide,

  // Uniforms: JS → GPU bridge. Updated every frame.
  uniforms: {
    uTime:  { value: 0.0 },                       // Elapsed time
    uMouse: { value: new THREE.Vector2(0, 0) },    // Normalized mouse position
    uResolution: { value: new THREE.Vector2(w, h) }, // Viewport size
    uColor: { value: new THREE.Color('#4dc9f6') },  // Any parameter
    uProgress: { value: 0.0 },                      // Transition progress 0-1
  },

  // Vertex shader: runs once per vertex, controls position
  vertexShader: `
    uniform float uTime;
    varying vec2 vUv;
    varying vec3 vPosition;

    void main() {
      vUv = uv;
      vPosition = position;

      vec3 pos = position;
      // ... vertex displacement here ...

      gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
    }
  `,

  // Fragment shader: runs once per pixel, controls color
  fragmentShader: `
    uniform float uTime;
    uniform vec2 uMouse;
    varying vec2 vUv;

    void main() {
      // ... color computation here ...
      gl_FragColor = vec4(color, alpha);
    }
  `,
});
```

#### Essential GLSL building blocks

These are the shader primitives that produce 90% of the effects you see on Active Theory's site:

**1. Simplex Noise** — organic, cloud-like randomness.
Used for: particle displacement, terrain, surface distortion, color variation.
Include the full 3D simplex noise function (Ashima Arts / Stefan Gustavson implementation) in a shared `noise.glsl` file.

**2. Fresnel** — edge glow based on view angle.
```glsl
float fresnel = pow(1.0 - abs(dot(viewDirection, normal)), exponent);
```
Used for: crystal/glass look, rim lighting, energy effects.

**3. Smoothstep** — smooth interpolation between two thresholds.
```glsl
float mask = smoothstep(0.0, 0.3, value); // Soft on
float edge = smoothstep(0.5, 0.48, dist);  // Sharp edge (narrow range)
```
Used for: soft edges, masks, thresholds, anti-aliasing.

**4. Distance fields** — soft circles for particles.
```glsl
float d = length(gl_PointCoord - 0.5);
float alpha = smoothstep(0.5, 0.0, d);
```

**5. Additive blending** — colors add to produce glow.
Set `blending: THREE.AdditiveBlending` and `depthWrite: false` on the material.
Dark pixels become transparent. Bright pixels glow.

**6. UV scrolling** — animated textures/patterns.
```glsl
vec2 uv = vUv + vec2(uTime * 0.1, 0.0); // Scroll horizontally
```

**7. Color mixing by attribute** — per-vertex or per-instance color variation.
```glsl
vec3 color = mix(colorA, colorB, vRandom);
```

### 4.6 Post-Processing Pipeline

Post-processing is what takes a scene from "looks like three.js" to "looks like Active Theory." The idea: render the scene to a texture (not the screen), then process that texture through one or more shader passes before displaying the final result.

```javascript
// gl/PostProcessing.js
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';

export class PostProcessing {
  constructor(renderer, scene, camera) {
    this.composer = new EffectComposer(renderer);

    // Pass 1: Render the 3D scene to a texture
    this.composer.addPass(new RenderPass(scene, camera));

    // Pass 2: Bloom (glow)
    const bloom = new UnrealBloomPass(
      new THREE.Vector2(window.innerWidth, window.innerHeight),
      0.8,   // strength — how much glow
      0.4,   // radius — how far glow spreads
      0.85   // threshold — brightness cutoff for what glows
    );
    this.composer.addPass(bloom);

    // Pass 3: Custom vignette + chromatic aberration
    const vignetteShader = {
      uniforms: {
        tDiffuse: { value: null },
        uIntensity: { value: 0.4 },
        uChromaticAberration: { value: 0.003 },
      },
      vertexShader: `
        varying vec2 vUv;
        void main() {
          vUv = uv;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform sampler2D tDiffuse;
        uniform float uIntensity;
        uniform float uChromaticAberration;
        varying vec2 vUv;

        void main() {
          // Chromatic aberration: offset R and B channels
          vec2 offset = (vUv - 0.5) * uChromaticAberration;
          float r = texture2D(tDiffuse, vUv + offset).r;
          float g = texture2D(tDiffuse, vUv).g;
          float b = texture2D(tDiffuse, vUv - offset).b;
          vec3 color = vec3(r, g, b);

          // Vignette: darken edges
          float dist = length(vUv - 0.5);
          float vignette = smoothstep(0.7, 0.3, dist);
          color *= mix(1.0 - uIntensity, 1.0, vignette);

          gl_FragColor = vec4(color, 1.0);
        }
      `,
    };
    this.composer.addPass(new ShaderPass(vignetteShader));
  }

  render() {
    this.composer.render();
  }
}
```

### 4.7 Scene Transitions

When navigating between rooms, several things happen simultaneously:

1. **Camera lerps** to the new room position (handled by Camera.js)
2. **DOM transitions** — scene label fades out, updates text, fades in
3. **Optional shader transition** — a full-screen shader effect (dissolve, wipe, glitch) can mask the cut
4. **Room lifecycle** — `onLeave()` for old room, `onEnter()` for new room

```javascript
// gl/SceneManager.js
export class SceneManager {
  constructor(camera, spacing) {
    this.scene = new THREE.Scene();
    this.rooms = [];
    this.camera = camera;
    this.spacing = spacing;
    this.activeIndex = 0;
  }

  addRoom(room) {
    this.rooms.push(room);
    this.scene.add(room.group);
  }

  goToRoom(index) {
    if (index === this.activeIndex) return;

    const prev = this.rooms[this.activeIndex];
    const next = this.rooms[index];

    prev.onLeave();
    next.onEnter();

    this.camera.setRoom(index, this.spacing);
    this.activeIndex = index;

    // Update DOM
    updateSceneLabel(index);
    updateNavDots(index);
  }

  update(time, mouse) {
    // Only update active room + neighbors for performance
    for (let i = 0; i < this.rooms.length; i++) {
      const dist = Math.abs(i - this.activeIndex);
      if (dist <= 1) {
        this.rooms[i].update(time, mouse);
      }
    }
  }
}
```

---

## 5. FOUR REFERENCE ROOMS

These are complete, production-ready room implementations covering the four most common effect categories. Each one demonstrates a different shader technique.

### Room 0: Nebula Field (Particle System + Noise Displacement)

**Technique**: `THREE.Points` with `BufferGeometry`. Per-particle attributes (`aRandom`, `aSize`) stored as buffer attributes. Vertex shader displaces particles using simplex noise. Fragment shader draws soft circles with additive blending.

**Key uniforms**: `uTime`, `uMouse`, `uColor1`, `uColor2`, `uPixelRatio`

**Vertex shader core logic**:
```glsl
// Noise-driven organic movement
float n = snoise(position * 0.3 + uTime * 0.15);
vec3 pos = position + normal * n * 0.8;

// Mouse repulsion
vec4 mvPos = modelViewMatrix * vec4(pos, 1.0);
float dist = length(mvPos.xy - uMouse * 3.0);
float push = smoothstep(2.0, 0.0, dist) * 0.5;
mvPos.xy += normalize(mvPos.xy - uMouse * 3.0 + 0.001) * push;

gl_PointSize = aSize * uPixelRatio * (80.0 / -mvPos.z);
```

**Fragment shader core logic**:
```glsl
float d = length(gl_PointCoord - 0.5);
float alpha = smoothstep(0.5, 0.0, d) * vAlpha;
vec3 color = mix(uColor1, uColor2, vRandom);
gl_FragColor = vec4(color, alpha);
```

**Geometry**: 4000–8000 points distributed in a sphere (`r = 2 + random * 4`).

### Room 1: Grid Horizon (Wireframe Terrain + Vertex Displacement)

**Technique**: `THREE.PlaneGeometry(20, 20, 80, 80)` with `wireframe: true`. Vertex shader applies layered noise for terrain elevation. Mouse position creates a ripple wave.

**Key uniforms**: `uTime`, `uMouse`

**Vertex shader core logic**:
```glsl
float elevation = snoise(vec3(pos.x * 0.15 + uTime * 0.05, pos.y * 0.15, uTime * 0.1)) * 2.0;
elevation += snoise(vec3(pos.x * 0.4, pos.y * 0.4 + uTime * 0.08, 0.0)) * 0.5;

// Mouse ripple
float mouseDist = length(pos.xy - uMouse * 10.0);
elevation += sin(mouseDist * 0.8 - uTime * 3.0) * 0.3 * smoothstep(6.0, 0.0, mouseDist);
pos.z = elevation;
```

**Fragment shader core logic**: Color mapped to elevation (`smoothstep`), edges faded by UV distance from center.

**Setup**: Plane rotated `-PI * 0.45` on X, positioned slightly below and behind camera.

### Room 2: Crystal Lattice (Instanced Geometry + Fresnel)

**Technique**: `THREE.InstancedBufferGeometry` with `IcosahedronGeometry(0.15, 0)` as the base. 200–400 instances. Per-instance attributes (`aOffset`, `aSeed`) control position and animation phase.

**Key uniforms**: `uTime`, `uMouse`

**Vertex shader core logic**:
```glsl
// Per-instance rotation
float angle = uTime * (0.3 + aSeed * 0.5);
mat3 rot = /* rotation matrix from angle */;
vec3 pos = rot * position + aOffset;

// Fresnel for edge glow
vec3 viewDir = normalize(-mvPosition.xyz);
vFresnel = pow(1.0 - abs(dot(viewDir, vNormal)), 2.0);
```

**Fragment shader core logic**: Two-color mix based on `aSeed`, alpha driven by fresnel. Produces a floating crystal field with glowing edges.

### Room 3: Void Sphere (Displacement + Glow Ring)

**Technique**: `IcosahedronGeometry(2, 64)` — high-poly sphere. Vertex shader applies multi-octave noise displacement along normals. Fragment shader maps color to displacement intensity with a fresnel rim.

**Vertex shader core logic**:
```glsl
float disp = snoise(pos * 1.5 + uTime * 0.2) * 0.3;
disp += snoise(pos * 3.0 - uTime * 0.3) * 0.15;
disp += snoise(pos * 6.0 + uTime * 0.5) * 0.05;
pos += normal * disp;
```

**Fragment shader core logic**: Dark base color, bright ridge colors mapped by `abs(vDisplacement)`, fresnel rim glow.

**Additional element**: A `RingGeometry` with additive blending behind the sphere for a halo/glow ring effect.

---

## 6. MOUSE INTERACTION PATTERN

Mouse position is tracked in normalized device coordinates (-1 to 1) and passed into shaders as a uniform. Always lerp the mouse value for smooth, weighted response.

```javascript
window.addEventListener('mousemove', (e) => {
  state.mouseTarget.x = (e.clientX / window.innerWidth) * 2 - 1;
  state.mouseTarget.y = -(e.clientY / window.innerHeight) * 2 + 1;
});

// In the render loop:
state.mouse.x += (state.mouseTarget.x - state.mouse.x) * 0.05;
state.mouse.y += (state.mouseTarget.y - state.mouse.y) * 0.05;
```

Touch devices: map `touchmove` to the same normalized coordinates. Consider using gyroscope data (`DeviceOrientationEvent`) as an alternative input for mobile.

---

## 7. PERFORMANCE TARGETS & OPTIMIZATION

| Metric | Target |
|--------|--------|
| Frame rate | 60fps on mid-range GPU, 30fps minimum on mobile |
| LCP | < 2s |
| Total JS bundle | < 300KB gzipped (excluding three.js) |
| Draw calls per frame | < 20 |
| Particle count | 4000–8000 on desktop, 1000–2000 on mobile |

### Optimization techniques

1. **Only update visible rooms** — check `Math.abs(roomIndex - activeIndex) <= 1` before calling `update()`.
2. **Use `InstancedMesh` / `InstancedBufferGeometry`** — one draw call for hundreds of objects.
3. **Limit pixel ratio** — `renderer.setPixelRatio(Math.min(devicePixelRatio, 2))`.
4. **Throttle post-processing on mobile** — reduce bloom resolution or disable chromatic aberration.
5. **Use `BufferGeometry` only** — never `Geometry` (deprecated and slow).
6. **Dispose on room transitions** — call `.dispose()` on geometries and materials when a room is far away, recreate on approach.
7. **Compress assets** — Draco for meshes, Basis/KTX2 for textures, gzip for shaders.

---

## 8. INTEGRATION STRATEGY FOR EXISTING SITES

### Phase 1: Foundation (Day 1–2)

1. **Install dependencies**: `three`, `gsap`, `lenis`, `vite-plugin-glsl` (if using Vite).
2. **Create the canvas layer**: A full-viewport `<canvas>` at `z-index: 0`, `position: fixed`.
3. **Move all existing UI** to `z-index: 10+` with `pointer-events: auto` only on interactive elements.
4. **Set up the render loop**: Single `requestAnimationFrame` loop. Even if nothing is in the scene yet, get the loop running.
5. **Set up resize handling**: Listen for `resize`, update renderer size, camera aspect, and any resolution-dependent uniforms.

### Phase 2: First Room (Day 2–3)

1. **Build one room** — start with the Nebula Field (particles are forgiving and look good quickly).
2. **Wire up mouse tracking** — normalized coords, lerped, passed as uniform.
3. **Add post-processing** — even just bloom transforms the look.
4. **Map existing content sections to rooms** — each page section becomes a room concept.

### Phase 3: Navigation (Day 3–4)

1. **Implement scroll-to-scene navigation** — wheel events trigger camera transitions.
2. **Add the camera lerp system** — exponential damping, frame-rate independent.
3. **Build navigation dots** — reflect current scene, allow click-to-jump.
4. **Add keyboard support** — arrow keys, spacebar.
5. **Sync DOM content** — scene labels, section content fade in/out with transitions.

### Phase 4: Polish (Day 4–7)

1. **Build remaining rooms** — one per content section, each with a distinct shader aesthetic.
2. **Add transition effects** — overlay fade, shader dissolve, or chromatic glitch during camera moves.
3. **Refine post-processing** — tune bloom threshold, add vignette, subtle chromatic aberration.
4. **Mobile optimization** — reduce particle counts, simplify shaders, throttle post-processing.
5. **Loading sequence** — show a loader while assets/shaders compile, then reveal with an entrance animation.
6. **Accessibility** — ensure all content is still accessible via DOM (screen readers should read the text layer). Add `prefers-reduced-motion` check to disable particle animation and camera lerp for users who need it.

### What will likely need refactoring in the existing codebase

- **CSS scroll-based layouts** → replaced by fixed-position canvas + overlay UI. All scroll behavior is captured and consumed by the WebGL scroll manager.
- **Section-based page structure** → content sections become metadata for rooms (title, subtitle, body text) rather than visible DOM sections.
- **Image-heavy layouts** → images can be loaded as textures and displayed on WebGL planes with shader effects, or kept as DOM elements floating above the canvas.
- **CSS animations/transitions** → replaced by GSAP timelines synchronized with the render loop.
- **Router** → if multi-page, either collapse to SPA with virtual routing, or use Barba.js for smooth inter-page transitions that preserve the WebGL context.

---

## 9. COMMON MISTAKES TO AVOID

1. **Using built-in materials** — `MeshStandardMaterial` is the single biggest reason sites "look like three.js." Use `ShaderMaterial` exclusively.
2. **Forgetting `depthWrite: false` on transparent objects** — causes z-fighting and visual artifacts.
3. **Not lerping the camera** — instant camera movement breaks immersion. Always interpolate.
4. **Hardcoded pixel ratios** — always cap at 2.0 and handle resize.
5. **Blocking the main thread during init** — compile shaders asynchronously, show a loading state.
6. **Ignoring mobile** — test on real devices. Reduce particle counts, simplify shaders, disable post-processing if needed.
7. **Putting interactive elements behind the canvas** — ensure DOM interactive elements have `pointer-events: auto` and sit above the canvas in z-order.
8. **Scroll jacking without escape** — always provide keyboard navigation and direct scene access (dot nav, URL hash) as alternatives to scroll.

---

## 10. SIMPLEX NOISE — SHARED GLSL INCLUDE

This is the Ashima Arts / Stefan Gustavson 3D simplex noise implementation. Include it in every shader that needs organic motion, terrain, or randomness.

```glsl
// noise.glsl — include via vite-plugin-glsl or paste into shader strings
vec3 mod289(vec3 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x*34.0)+1.0)*x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) {
  const vec2 C = vec2(1.0/6.0, 1.0/3.0);
  const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
  vec3 i = floor(v + dot(v, C.yyy));
  vec3 x0 = v - i + dot(i, C.xxx);
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min(g.xyz, l.zxy);
  vec3 i2 = max(g.xyz, l.zxy);
  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy;
  vec3 x3 = x0 - D.yyy;
  i = mod289(i);
  vec4 p = permute(permute(permute(
    i.z + vec4(0.0, i1.z, i2.z, 1.0))
    + i.y + vec4(0.0, i1.y, i2.y, 1.0))
    + i.x + vec4(0.0, i1.x, i2.x, 1.0));
  float n_ = 0.142857142857;
  vec3 ns = n_ * D.wyz - D.xzx;
  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_);
  vec4 x = x_ * ns.x + ns.yyyy;
  vec4 y = y_ * ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);
  vec4 b0 = vec4(x.xy, y.xy);
  vec4 b1 = vec4(x.zw, y.zw);
  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));
  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww;
  vec3 p0 = vec3(a0.xy, h.x);
  vec3 p1 = vec3(a0.zw, h.y);
  vec3 p2 = vec3(a1.xy, h.z);
  vec3 p3 = vec3(a1.zw, h.w);
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0),dot(p1,p1),dot(p2,p2),dot(p3,p3)));
  p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
  vec4 m = max(0.6 - vec4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot(m*m, vec4(dot(p0,x0),dot(p1,x1),dot(p2,x2),dot(p3,x3)));
}
```

---

## 11. AGENT INSTRUCTIONS

When integrating this system into an existing codebase:

1. **Read the existing codebase first.** Understand what framework is in use (React, Vue, Svelte, vanilla), what build tool, and what the current page structure is. The integration approach differs significantly between SPA frameworks and static sites.

2. **Do not discard existing content.** Every piece of content the user currently has (text, images, sections) should appear in the final result — either as DOM overlays or as textures/data feeding into WebGL rooms.

3. **Start with the canvas layer.** Get a black full-viewport canvas rendering before touching anything else. Confirm the render loop runs at 60fps with nothing in the scene.

4. **Implement one room end-to-end** before building the rest. The Nebula Field (particles) is the most forgiving starting point. Get it rendering, responding to mouse, and looking good with bloom before building more rooms.

5. **Map content sections to rooms.** Each major section of the existing site becomes a room. The room's visual theme should relate to the content (e.g., a "team" section might use the Crystal Lattice, a "hero" section might use the Void Sphere).

6. **Preserve accessibility.** All text content must remain in the DOM layer, readable by screen readers. The WebGL layer is purely visual. Add `prefers-reduced-motion` detection.

7. **Test on mobile early.** Not after everything is built. Reduce particle counts, simplify or disable post-processing, and test touch navigation from the start.

8. **If the existing site uses React**: Use `useRef` for the canvas container, `useEffect` for init/cleanup, and keep the three.js render loop outside of React's render cycle. Do not put three.js objects in React state — this causes unnecessary re-renders. Consider `@react-three/fiber` only if the team is already familiar with it; otherwise, vanilla three.js inside a React component is simpler and more predictable.

9. **If the existing site uses Next.js / SSR**: The WebGL layer must be client-only. Use `dynamic(() => import('./WebGLCanvas'), { ssr: false })` or equivalent. All three.js code runs in `useEffect` or a client component.

10. **If the existing site is vanilla HTML/CSS/JS**: This is the simplest integration path. Follow the file structure in Section 3 directly.

---

## 12. QUALITY CHECKLIST

Before considering the integration complete, verify:

- [ ] Canvas covers full viewport, fixed position, behind all UI
- [ ] Render loop runs at 60fps on desktop, 30fps+ on mobile
- [ ] Mouse/touch input drives shader uniforms with smooth lerp
- [ ] Camera transitions between rooms with exponential damping
- [ ] Each room has a unique shader aesthetic (no MeshStandard/Phong)
- [ ] Post-processing active: bloom at minimum, vignette recommended
- [ ] Scroll, keyboard, and click navigation all work
- [ ] Navigation dots/indicators reflect current scene
- [ ] Scene labels/content update on transition
- [ ] Mobile touch navigation works
- [ ] `prefers-reduced-motion` disables animation
- [ ] All text content accessible via DOM (screen reader compatible)
- [ ] No console errors or WebGL warnings
- [ ] Assets compressed (textures, meshes, shaders)
- [ ] Loading state shown during init/shader compilation
- [ ] Resize handling updates renderer, camera aspect, and resolution uniforms
