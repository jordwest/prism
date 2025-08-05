import { FresnelInstance } from "./instance";

export function createInputImports(instance: FresnelInstance) {
  return {
    is_action_just_pressed: (actionId: number): boolean => {
      return instance.input.pressedActionsThisFrame.has(actionId);
    },
  };
}
