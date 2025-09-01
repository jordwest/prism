import { FresnelInstance } from "./instance";
import { I32Pointer, OdinSlicePointer, OdinStringPointer } from "./types";
import { NET_FAKE_DELAY } from "../index";
import { getSlice, readOdinString, writeI32, writeOdinString } from "./util";

// const delayMs = () => 0;
const delayMs = () => NET_FAKE_DELAY;
// const delayMs = () => 150;

export function createNetImports(instance: FresnelInstance) {
  return {
    client_send_message: (msgPtr: OdinSlicePointer) => {
      if (!instance.peer.isConnected()) return;

      const messageContent = getSlice(instance.memory, msgPtr);

      const data = messageContent.slice();

      instance.peer.send(data);

      return messageContent.length;
    },
    client_poll_message: (msgPtr: OdinSlicePointer) => {
      const message = instance.peer.poll();
      if (message == null) return 0;

      const destination = getSlice(instance.memory, msgPtr);

      if (message.length > destination.length) {
        return -2;
      }

      destination.set(message);
      return message.length;
    },

    client_connect: (connectionPathPtr: OdinStringPointer) => {
      const path = readOdinString(instance.memory, connectionPathPtr);
      instance.peer.connect(path)
    },

    server_listen: () => {
      instance.hostPeer.listen();
    },

    server_connection_path: (ptr: OdinSlicePointer): number => {
      if (instance.hostPeer.connectionPath == null) return 0

      return writeOdinString(instance.hostPeer.connectionPath, instance.memory, ptr);
    },

    server_send_message: (clientId: number, msgPtr: OdinSlicePointer): boolean => {
      const messageContent = getSlice(instance.memory, msgPtr);
      const data = messageContent.slice();
      return instance.hostPeer.send(clientId, data);
    },

    server_broadcast_message: (msgPtr: OdinSlicePointer) => {
      const messageContent = getSlice(instance.memory, msgPtr);

      const data = messageContent.slice();
      instance.hostPeer.broadcast(data);
      return messageContent.length;
    },
    server_poll_message: (
      clientIdPtr: I32Pointer,
      msgPtr: OdinSlicePointer,
    ) => {
      const message = instance.hostPeer.poll();
      if (message == null) return 0;

      const [clientId, data] = message;

      const destination = getSlice(instance.memory, msgPtr);
      if (data.length > destination.length) {
        return -2;
      }

      writeI32(instance.memory, clientIdPtr, clientId);

      destination.set(data);
      return data.length;
    },
  };
}
