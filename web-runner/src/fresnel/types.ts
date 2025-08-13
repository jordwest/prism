export type Mailbox = Uint8Array<ArrayBuffer>[];
export type ServerMailbox = {
  clientId: number;
  data: Uint8Array<ArrayBuffer>;
}[];

export type FresnelState = {
  canvas: HTMLCanvasElement;
  canvasContext: CanvasRenderingContext2D;
  font: string;
  storage: Record<string, string>;
  serverMailbox: ServerMailbox;
  mailboxes: Map<number, Mailbox>;
  assets: Record<number, Asset>;
  audioContext: AudioContext;
  input: {
    keyToAction: Map<string, number>;
    mouseButtonToAction: Map<number, number>;
  };
};

export type Asset = ImageAsset | AudioAsset;
export type ImageAsset = {
  type: "image";
  image: ImageBitmap;
};
export type AudioAsset = {
  type: "audio";
  audioElement: HTMLAudioElement;
};

export type ManifestJson = {
  font: string;
  assets: ManifestAsset[];
  input: {
    actions: ManifestAction[];
  };
};
export type AssetType = "image" | "audio";
export type ManifestAsset = {
  id: number;
  filename: string;
  type: AssetType;
};
export type ManifestAction = {
  id: number;
  name?: string;
  webKeys?: string[];
  mouseButtons?: number[];
};

export type Pointer = number & { __pointer: never };
export type OdinStringPointer = number & {
  __odinStringPointer: never;
  __odinSlicePointer: never;
};
export type OdinSlicePointer = number & { __odinSlicePointer: never };
export type I32Pointer = number & { __i32Pointer: never };

export type FresnelExports = {
  on_mouse_move?: (x: number, y: number, down: boolean) => void;
  on_mouse_button?: (
    x: number,
    y: number,
    down: boolean,
    button: number,
  ) => void;
  on_resize?: (w: number, h: number) => void;

  on_client_connected?: (clientId: number) => void;

  /**
   * Called on the old module when hot reloading, use this to store any state so it
   * can be reloaded when booting again
   */
  on_dev_hot_unload?: () => void;
  tests?: () => void;
  tick: (delta_time: number) => void;
  boot: (w: number, h: number, flags: number) => void;
};
