export type FresnelState = {
  canvas: HTMLCanvasElement;
  canvasContext: CanvasRenderingContext2D;
};

export type Pointer = number & { __pointer: never };
export type OdinStringPointer = number & { __odinStringPointer: never };

export type FresnelExports = {
  on_mouse_update?: (x: number, y: number, down: boolean) => void;
  on_resize?: (w: number, h: number) => void;
  tick: (delta_time: number) => void;
  boot: (w: number, h: number) => void;
};
