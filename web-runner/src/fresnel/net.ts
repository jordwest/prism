import { FresnelInstance } from "./instance";
import { FresnelState, Mailbox } from "./types";
import { I32Pointer, OdinSlicePointer } from "./types";
import { getSlice, writeI32 } from "./util";

const getMailbox = (state: FresnelState, clientId: number): Mailbox => {
  const mailboxes = state.mailboxes;
  if (!mailboxes.has(clientId)) {
    mailboxes.set(clientId, []);
  }

  return mailboxes.get(clientId)!;
};

// const delayMs = () => 0;
const delayMs = () => 50;
// const delayMs = () => 150;

export function createNetImports(instance: FresnelInstance) {
  return {
    client_send_message: (msgPtr: OdinSlicePointer) => {
      const messageContent = getSlice(instance.memory, msgPtr);

      const data = messageContent.slice();
      setTimeout(() => {
        instance.state.serverMailbox.push({
          clientId: instance.instanceId + 1,
          data,
        });
      }, delayMs());

      return messageContent.length;
    },
    client_poll_message: (msgPtr: OdinSlicePointer) => {
      const clientMailbox = getMailbox(instance.state, instance.instanceId + 1);

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

    server_send_message: (clientId: number, msgPtr: OdinSlicePointer) => {
      const messageContent = getSlice(instance.memory, msgPtr);

      const clientMailbox = getMailbox(instance.state, clientId);
      const data = messageContent.slice();
      setTimeout(() => {
        clientMailbox.push(data);
      }, delayMs());

      return messageContent.length;
    },
    server_broadcast_message: (msgPtr: OdinSlicePointer) => {
      const messageContent = getSlice(instance.memory, msgPtr);

      const data = messageContent.slice();
      for (var clientId of instance.state.mailboxes.keys()) {
        const clientMailbox = getMailbox(instance.state, clientId);
        setTimeout(() => {
          clientMailbox.push(data);
        }, delayMs());
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
