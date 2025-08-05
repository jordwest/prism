export type Mailbox = Uint8Array<ArrayBuffer>[];
export type ServerMailbox = {
  clientId: number;
  data: Uint8Array<ArrayBuffer>;
}[];

export type FresnelState = {
  canvas: HTMLCanvasElement;
  canvasContext: CanvasRenderingContext2D;
  storage: Record<string, string>;
  serverMailbox: ServerMailbox;
  mailboxes: Map<number, Mailbox>;
  images: Record<number, ImageBitmap>;
  input: {
    keyToAction: Map<string, number>;
  };
};

export type ManifestJson = {
  assets: ManifestAsset[];
  input: {
    actions: ManifestAction[];
  };
};
export type ManifestAsset = {
  id: number;
  filename: string;
};
export type ManifestAction = {
  id: number;
  name?: string;
  webKeys?: string[];
};

export type Pointer = number & { __pointer: never };
export type OdinStringPointer = number & {
  __odinStringPointer: never;
  __odinSlicePointer: never;
};
export type OdinSlicePointer = number & { __odinSlicePointer: never };
export type I32Pointer = number & { __i32Pointer: never };

export type FresnelExports = {
  on_mouse_update?: (x: number, y: number, down: boolean) => void;
  on_resize?: (w: number, h: number) => void;

  on_client_connected?: (clientId: number) => void;

  /**
   * Called on the old module when hot reloading, use this to store any state so it
   * can be reloaded when booting again
   */
  on_dev_hot_unload?: () => void;
  tick: (delta_time: number) => void;
  boot: (w: number, h: number, flags: number) => void;
};
