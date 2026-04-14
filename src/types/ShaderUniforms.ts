import type { Color, Vector2 } from 'three';

export interface BaseUniforms {
  uTime: { value: number };
  uMouse: { value: Vector2 };
  uResolution: { value: Vector2 };
  uProgress: { value: number };
}

export interface NebulaUniforms extends BaseUniforms {
  uColor1: { value: Color };
  uColor2: { value: Color };
  uPixelRatio: { value: number };
}

export interface GridUniforms extends BaseUniforms {
  uColor1: { value: Color };
  uColor2: { value: Color };
}

export interface CrystalUniforms extends BaseUniforms {
  uColor1: { value: Color };
  uColor2: { value: Color };
}