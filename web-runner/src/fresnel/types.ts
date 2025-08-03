export type FresnelState = {
  canvas: HTMLCanvasElement;
  canvasContext: CanvasRenderingContext2D;
};

export type Pointer = number & { __pointer: never };
export type OdinStringPointer = number & {
  __odinStringPointer: never;
  __odinSlicePointer: never;
};
export type OdinSlicePointer = number & { __odinSlicePointer: never };

export type FresnelExports = {
  on_mouse_update?: (x: number, y: number, down: boolean) => void;
  on_resize?: (w: number, h: number) => void;

  /**
   * Called on the old module when hot reloading, use this to store any state so it
   * can be reloaded when booting again
   */
  on_dev_hot_unload?: () => void;
  tick: (delta_time: number) => void;
  boot: (w: number, h: number) => void;
};
