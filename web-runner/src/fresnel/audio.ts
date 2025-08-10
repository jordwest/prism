import { FresnelInstance } from "./instance";

export function createAudioImports(instance: FresnelInstance) {
  return {
    play(audioId: number) {
      const asset = instance.state.assets[audioId];
      if (asset?.type !== "audio") {
        console.error("Tried to play non-audio asset id=", audioId, asset);
        return;
      }

      const el = asset.audioElement;
      if (!el.paused) {
        el.currentTime = 0;
      }
      el.play();
    },
  };
}
