const { emit, getToolFilePath, readHookPayload, toPosixPath } = require("./hookUtils.cjs");

const RULES = [
  {
    test: (p) => p.includes("/shaders/"),
    context:
      "SHADER FILE EDITED. Verify: (1) no inline GLSL strings in component files, (2) shared noise/fresnel functions imported from includes/, (3) all uniforms typed in ShaderUniforms.ts, (4) uniforms include at minimum uTime, uMouse, uResolution.",
  },
  {
    test: (p) => p.includes("/components/three/"),
    context:
      "THREE.JS COMPONENT EDITED. Verify: (1) all geometries/materials/textures disposed on unmount, (2) no Three.js objects stored in Zustand state (use refs), (3) no built-in materials (MeshStandard/Phong) — ShaderMaterial only, (4) InstancedMesh for >100 identical objects, (5) only updates when active or adjacent room.",
  },
  {
    test: (p) => p.includes("/stores/"),
    context:
      "ZUSTAND STORE EDITED. Verify: (1) no Three.js objects in state (geometries, materials, textures, meshes), (2) components subscribe to specific slices, not the whole store.",
  },
];

async function main() {
  const payload = await readHookPayload();
  const f = toPosixPath(getToolFilePath(payload));
  if (!f) return;
  const m = RULES.find((r) => r.test(f));
  if (m) emit({ hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: m.context } });
}

main().catch((e) => {
  process.stderr.write(`[hook] post-tool-use failed: ${e.message}\n`);
  process.exitCode = 0;
});
