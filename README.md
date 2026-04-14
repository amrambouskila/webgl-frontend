# WebGL Immersive Navigation Framework

A React + Three.js + TypeScript framework that transforms websites into immersive 3D experiences. Users navigate between "rooms" — distinct 3D scenes with custom GLSL shaders, scroll-driven camera animation, and post-processing effects. Inspired by Active Theory's approach.

**This is not "sprinkle WebGL onto a webpage."** The webpage lives inside the WebGL world.

---

## Architecture

```mermaid
graph TD
    subgraph Browser
        subgraph DOM["DOM Overlay (z-index: 10)"]
            Nav[Navigation Dots]
            Labels[Scene Labels]
        end

        subgraph Canvas["WebGL Canvas (z-index: 0)"]
            R3F[React Three Fiber]
            Camera[Camera Rig]
            PostFX[Post-Processing]

            subgraph Rooms
                R0[Nebula Field]
                R1[Grid Horizon]
                R2[Crystal Lattice]
            end
        end

        subgraph State["Zustand Stores"]
            NavStore[Navigation]
            InputStore[Input]
        end
    end

    Nav --> NavStore
    Camera --> NavStore
    Camera --> InputStore
    Rooms --> InputStore
    PostFX --> R3F
```

### Room Navigation

```mermaid
sequenceDiagram
    participant User
    participant Scroll as Scroll Hook
    participant Store as Navigation Store
    participant Camera as Camera Rig
    participant Room as Target Room

    User->>Scroll: Scroll / Arrow Key / Click
    Scroll->>Store: goToScene(N)
    Store-->>Camera: Target = Room N position
    Camera->>Camera: Exponential lerp to target
    Store-->>Room: active = true
    Room->>Room: Resume uniform updates
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| 3D | Three.js via @react-three/fiber + @react-three/drei |
| Shaders | Custom GLSL (ShaderMaterial only — no built-in materials) |
| Animation | GSAP + ScrollTrigger |
| Scroll | Lenis (smooth momentum scrolling) |
| Post-processing | @react-three/postprocessing (bloom, chromatic aberration, vignette) |
| State | Zustand |
| Build | Vite + vite-plugin-glsl |
| Language | TypeScript strict mode |
| Testing | Vitest + React Testing Library |
| Package Manager | pnpm |

---

## Rooms

### Room 0: Nebula Field
Particle cloud with simplex noise displacement and mouse repulsion. 4000-8000 points with additive blending and soft circles. Two-color gradient driven by per-particle random attribute.

### Room 1: Grid Horizon
Wireframe terrain with layered noise elevation. Mouse position creates a ripple wave. Color mapped to elevation with UV edge fade.

### Room 2: Crystal Lattice
200-400 instanced icosahedrons with per-instance rotation and orbital motion. Fresnel edge glow produces floating crystal field with glowing edges.

---

## Phase Roadmap

```mermaid
graph LR
    P1["Phase 1<br/>Core Framework<br/>+ 3 Rooms"] --> P2["Phase 2<br/>Content<br/>Integration"]
    P2 --> P3["Phase 3<br/>Performance<br/>+ Mobile"]

    style P1 fill:#4dc9f6,stroke:#333,color:#000
    style P2 fill:#666,stroke:#333,color:#fff
    style P3 fill:#666,stroke:#333,color:#fff
```

| Phase | Focus | Status |
|-------|-------|--------|
| **1** | Renderer, camera, scroll nav, post-processing, 3 rooms | **In Progress** |
| 2 | DOM overlays, content mapping, loading states, 4th room | Planned |
| 3 | Mobile optimization, device detection, accessibility | Planned |

---

## Running Locally

### Without Docker

```bash
pnpm install
pnpm dev        # http://localhost:5173
```

### With Docker

```bash
# macOS / Linux
./run_webgl_frontend.sh

# Windows
run_webgl_frontend.bat
```

The launcher builds and starts the container, then presents a menu:
- `[k]` Stop, keep images
- `[q]` Stop, remove images
- `[v]` Full cleanup (images + volumes)
- `[r]` Full restart (rebuild + relaunch)

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Frame rate | 60fps desktop, 30fps mobile |
| LCP | < 2s |
| Bundle (excl. Three.js) | < 300KB gzipped |
| Draw calls / frame | < 20 |

---

## Project Structure

```
src/
├── components/
│   ├── ui/          # DOM overlay (NavigationDots)
│   └── three/       # R3F components (Experience, CameraRig, rooms, post-processing)
├── hooks/           # useScrollNavigation, useMouseTracking
├── stores/          # Zustand stores (navigation, input)
├── shaders/         # GLSL files (.vert, .frag, .glsl)
│   └── includes/    # Shared GLSL (noise, fresnel)
├── types/           # TypeScript interfaces
└── workers/         # Web Workers (future)
```