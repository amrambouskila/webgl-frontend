import { Canvas } from '@react-three/fiber';

export function App(): JSX.Element {
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      {/* WebGL Layer (z-index: 0) */}
      <Canvas
        style={{ position: 'fixed', top: 0, left: 0, zIndex: 0 }}
        gl={{ antialias: true, alpha: false }}
        dpr={[1, 2]}
        camera={{ fov: 60, near: 0.1, far: 500, position: [0, 0, 8] }}
      >
        {/* Experience component will be added here */}
      </Canvas>

      {/* DOM Overlay Layer (z-index: 10) */}
      <div
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          zIndex: 10,
          pointerEvents: 'none',
        }}
      >
        {/* NavigationDots and other DOM overlays will be added here */}
      </div>
    </div>
  );
}