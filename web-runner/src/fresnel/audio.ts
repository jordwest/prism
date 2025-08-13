import { FresnelInstance } from "./instance";

export function createAudioImports(instance: FresnelInstance) {
  return {
    play(audioId: number, restart: boolean) {
      const asset = instance.state.assets[audioId];
      if (asset?.type !== "audio") {
        console.error("Tried to play non-audio asset id=", audioId, asset);
        return;
      }

      const el = asset.audioElement;
      if (!el.paused) {
        if (!restart) {
          // Do nothing since already playing
          return
        }
      }

      el.currentTime = 0;
      safePlay(el);
    },
    stop(audioId: number) {
      const asset = instance.state.assets[audioId];
      if (asset?.type !== "audio") {
        console.error("Tried to play non-audio asset id=", audioId, asset);
        return;
      }

      const el = asset.audioElement;
      if (el.paused) return;

      el.pause()
    }
  };
}

const safePlay = async (el: HTMLAudioElement) => {
  try {
    await el.play();
  } catch (e) {
    console.error("Failed to play audio", e);
  }
};
