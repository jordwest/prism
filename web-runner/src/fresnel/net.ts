import { FresnelInstance } from "./instance";
import { ClientId, I32Pointer, OdinSlicePointer } from "./types";
import { NET_FAKE_DELAY } from "../index";
import { getSlice, writeI32 } from "./util";

// const delayMs = () => 0;
const delayMs = () => NET_FAKE_DELAY;
// const delayMs = () => 150;

export function createNetImports(instance: FresnelInstance) {
  return {
    client_send_message: (msgPtr: OdinSlicePointer) => {
      if (!instance.connected) return;

      const messageContent = getSlice(instance.memory, msgPtr);

      // Fake "localhost" has no delay
      const sendingToLocalhost = instance.instanceId == instance.state.listeningServerId

      const data = messageContent.slice();
      setTimeout(() => {
        instance.state.serverMailbox.push({
          clientId: instance.clientId,
          data,
        });
      }, sendingToLocalhost ? 0 : delayMs());

      return messageContent.length;
    },
    client_poll_message: (msgPtr: OdinSlicePointer) => {
      const clientMailbox = instance.state.clients.get(instance.clientId);
      if (clientMailbox == null) {
        return 0
      }

      const message = clientMailbox.shift();
      if (message == null) {
        return 0;
      }

      const destination = getSlice(instance.memory, msgPtr);

      if (message.length > destination.length) {
        return -2;
      }

      destination.set(message);
      return message.length;
    },

    client_connect: () => {
      if (instance.state.listeningServerId != null) {
        instance.connected = true
        const clientId = instance.state.nextClientId
        instance.state.nextClientId++
        instance.clientId = clientId;
        instance.state.clients.set(clientId, [])

        const host = instance.state.instances[instance.state.listeningServerId];
        if (host != null) {
          host.exports.on_client_connected?.(clientId);
        }
      }
    },

    server_listen: () => {
      console.info("Server listening")
      instance.state.listeningServerId = instance.instanceId
    },

    server_send_message: (clientId: number, msgPtr: OdinSlicePointer): boolean => {
      const messageContent = getSlice(instance.memory, msgPtr);

      const clientMailbox = instance.state.clients.get(clientId as ClientId);
      const data = messageContent.slice();

      if (clientMailbox == null) return false

      // Fake "localhost" has no delay
      const sendingToLocalhost = instance.clientId === clientId

      setTimeout(() => {
        clientMailbox.push(data);
      }, sendingToLocalhost ? 0 : delayMs());
      return true;
    },
    server_broadcast_message: (msgPtr: OdinSlicePointer) => {
      const messageContent = getSlice(instance.memory, msgPtr);

      const data = messageContent.slice();
      for (var clientId of instance.state.clients.keys()) {
        const sendingToLocalhost = instance.clientId === clientId
        const clientMailbox = instance.state.clients.get(clientId)!;
        setTimeout(() => {
          clientMailbox.push(data);
        }, sendingToLocalhost ? 0 : delayMs());
      }

      return messageContent.length;
    },
    server_poll_message: (
      clientIdPtr: I32Pointer,
      msgPtr: OdinSlicePointer,
    ) => {
      const message = instance.state.serverMailbox.shift();
      if (message == null) {
        return 0;
      }

      const destination = getSlice(instance.memory, msgPtr);

      if (message.data.length > destination.length) {
        return -2;
      }

      writeI32(instance.memory, clientIdPtr, message.clientId);

      destination.set(message.data);
      return message.data.length;
    },
  };
}
