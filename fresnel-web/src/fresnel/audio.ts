import { FresnelInstance } from "./instance";
import { OdinSlicePointer } from "./types";
import { getSlice, getSliceDataView } from "./util";

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

    play_ex(audio_data: OdinSlicePointer) {
      const data = getSliceDataView(instance.memory, audio_data)
      const buf = instance.state.audioContext.createBuffer(1, data.byteLength / 2, 16769);
      const bufData = buf.getChannelData(0)
      const sampleCount = data.byteLength / 2;

      for (let i = 0; i < sampleCount; i++) {
        const sample = ((data.getInt16(i * 2, true) ?? 0) / 32767) * 1.0
        if (sample > -1.0 && sample < 1.0) {
          bufData[i] = sample
        } else {
          bufData[i] = 0
        }
      }

      const node = instance.state.audioContext.createBufferSource()
      // node.loopStart = 0.001
      // node.loopEnd = 0.03
      // node.loop = true;
      node.buffer = buf;
      node.connect(instance.state.audioContext.destination)
      node.start(instance.state.audio.bufferedUpToTime)
      instance.state.audio.bufferedUpToTime += sampleCount / instance.state.audio.sampleRate;

      // safePlay(el);
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
