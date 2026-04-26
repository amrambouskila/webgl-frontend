---
name: validate
description: Validate WebGL/shader code for correctness and completeness
---

# Validate Command

Before anything else:
1. Re-read `AGENTS.md` in full.
2. Re-read `docs/WEBGL_FRONTEND_MASTER_PLAN.md`.
3. Re-read `webgl-immersive-integration-prompt.md` for reference shader implementations.

## Multi-Layer Inspection

### Layer 1: Structural Completeness

For each room:
- [ ] Component file exists in `src/components/three/`
- [ ] Vertex shader exists in `src/shaders/`
- [ ] Fragment shader exists in `src/shaders/`
- [ ] Component implements `RoomProps` interface
- [ ] Group positioned at correct Y offset (`-index * spacing`)
- [ ] Uniforms updated only when active or adjacent

For the pipeline:
- [ ] CameraRig uses exponential lerp (not flat factor)
- [ ] Post-processing includes bloom + at least one custom pass
- [ ] Navigation store tracks currentScene, targetScene, transitioning
- [ ] Input store tracks mouse, mouseTarget, time

### Layer 2: Shader Correctness

For each shader pair:
- [ ] Vertex shader writes `gl_Position` correctly (projectionMatrix * modelViewMatrix * vec4)
- [ ] Fragment shader writes `gl_FragColor` (or uses out variable for WebGL2)
- [ ] All `uniform` declarations match the TypeScript uniform definitions
- [ ] All `varying` declarations in vertex shader have matching declarations in fragment shader
- [ ] `vUv` is passed if UV coordinates are needed
- [ ] Noise function is imported from `includes/noise.glsl`, not copy-pasted

### Layer 3: Performance Compliance

- [ ] Particle rooms use `THREE.Points` or `InstancedMesh`, not individual meshes
- [ ] Instanced geometry rooms use `InstancedBufferGeometry` or `<instancedMesh>`
- [ ] No Python-loop equivalent (no per-particle JS iteration in render loop)
- [ ] Pixel ratio capped at `Math.min(devicePixelRatio, 2)`
- [ ] Distant rooms freeze uniforms (not updating uTime/uMouse when >1 room away)

### Layer 4: Reference Validation

Compare each room's shader against the reference implementations in `webgl-immersive-integration-prompt.md`:
- Nebula: particles with noise displacement + mouse repulsion + soft circles + additive blending
- Grid: wireframe plane with layered noise elevation + mouse ripple + elevation color mapping
- Crystal: instanced icosahedrons with per-instance rotation + fresnel glow

Flag any deviations from the spec and explain whether they are intentional improvements or regressions.

## Output

Report findings organized by layer. For each issue, provide:
- File and line number
- What's wrong
- What the spec says it should be
- Suggested fix