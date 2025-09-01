import { FresnelInstance } from "./instance";
import { OdinSlicePointer, OdinStringPointer } from "./types";
import { getSlice, readOdinString } from "./util";

export function createInputImports(instance: FresnelInstance) {
  return {
    is_action_just_pressed: (actionId: number): boolean => {
      return instance.input.pressedActionsThisFrame.has(actionId);
    },
    is_action_pressed: (actionId: number): boolean => {
      return instance.input.pressedActions.has(actionId);
    },

    read_input: (ptr: OdinSlicePointer): number => {
      const destSlice = getSlice(instance.memory, ptr);
      const bytes = new TextEncoder().encode(instance.input.inputBoxState.value);
      if (bytes.length > destSlice.length) {
        const subset = new Uint8Array(bytes.buffer, bytes.byteOffset, destSlice.length);
        destSlice.set(subset)
        return destSlice.length
      }

      destSlice.set(bytes)
      return bytes.length
    },
    render_input: (x: number, y: number, width: number, size: number, text: OdinStringPointer) => {
      const inputState = instance.input.inputBoxState;

      let setTextTo = "";
      if (text != null || text > 0) {
        setTextTo = readOdinString(instance.memory, text);
      }

      if (inputState.value != setTextTo) {
        const inputElement = inputState.element;
        const currentCaretPosition = inputElement.selectionStart;
        const previousTextLength = inputState.value.length;

        inputElement.value = setTextTo;
        inputState.value = setTextTo;

        // Preserve caret position if new text is same length or longer
        if (setTextTo.length >= previousTextLength && currentCaretPosition !== null) {
          inputElement.setSelectionRange(currentCaretPosition, currentCaretPosition);
        }
      }

      if (x == inputState.x && y == inputState.y && size == inputState.size && inputState.visible) {
        // Already in the right place
        return;
      }

      inputState.x = x
      inputState.y = y
      inputState.size = size
      inputState.visible = true

      const input = instance.input.inputBoxState.element;
      input.style.left = `${x}px`;
      input.style.top = `${y + instance.state.canvas.height * instance.region.y}px`;
      input.style.width = `${width}px`;
      input.style.height = `${size}px`;
      input.style.fontSize = `${size}px`;
      input.style.fontFamily = instance.state.font;
      input.hidden = false;
      input.focus()
    },
    remove_input: () => {
      const inputState = instance.input.inputBoxState;
      if (!inputState.visible) {
        // Already in the right place
        return;
      }

      inputState.visible = false;
      inputState.element.hidden = true;
    }
  };
}
