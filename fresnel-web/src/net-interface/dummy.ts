import { NetPeer, ClientId } from "./interface";
import { toBase94, fromBase94, Base94EncodedString } from "../base94";

export type Mailbox = Base94EncodedString[];
export type ServerMailbox = {
  clientId: ClientId;
  data: Base94EncodedString;
}[];

const mailboxes: Map<ClientId, Mailbox> = new Map();
const serverMailbox: ServerMailbox = [];
let listeningPeer: DummyNetPeer | null = null
let nextClientId = 100;

/**
 * Doesn't send messages anywhere, just for running multiple instances in a single tab
 */
export class DummyNetPeer implements NetPeer {
  _fakeDelay: number;
  _instanceId: number;
  _clientId: ClientId | null = null;
  _connected: boolean = false;

  clientConnectedHandler: ((clientId: ClientId) => void) | null = null;

  constructor(fakeDelay: number, instanceId: number) {
    this._fakeDelay = fakeDelay;
    this._instanceId = instanceId;
  }

  isConnected() {
    return this._connected;
  }

  startHosting() {
    console.info("DummyNetPeer listening")
    listeningPeer = this;
  }

  connect(): number | null {
    console.warn(this._clientId, this._instanceId, "Connect");
    if (listeningPeer != null) {
      this._connected = true
      const clientId = nextClientId as ClientId
      nextClientId++
      this._clientId = clientId;

      mailboxes.set(clientId, [])

      listeningPeer.clientConnectedHandler?.(clientId);
      return clientId
    }
    console.error("Connection attempted but dummy server not listening")

    return null
  }

  sendToHost(message: Uint8Array): void {
    // Fake "localhost" has no delay
    const sendingToLocalhost = listeningPeer == this;
    if (this._clientId == null) { return }

    setTimeout(() => {
      serverMailbox.push({
        clientId: this._clientId!,
        data: toBase94(message),
      });
    }, sendingToLocalhost ? 0 : this._fakeDelay);
  }

  onClientConnected(handler: (clientId: ClientId) => void): void {
    this.clientConnectedHandler = handler;
  }

  sendToClient(clientId: ClientId, message: Uint8Array): boolean {
    const clientMailbox = mailboxes.get(clientId);

    if (clientMailbox == null) return false

    // Fake "localhost" has no delay
    const sendingToLocalhost = this._clientId === clientId

    setTimeout(() => {
      clientMailbox.push(toBase94(message));
    }, sendingToLocalhost ? 0 : this._fakeDelay);

    return true;
  }

  broadcast(message: Uint8Array): void {
    for (var clientId of mailboxes.keys()) {
      const clientMailbox = mailboxes.get(clientId)!;
      setTimeout(() => {
        clientMailbox.push(toBase94(message));
      }, this._fakeDelay);
    }
  }

  clientPoll(): Uint8Array | null {
    if (this._clientId == null) return null;

    const clientMailbox = mailboxes.get(this._clientId);
    if (clientMailbox == null) {
      return null;
    }

    const message = clientMailbox.shift();
    if (message == null) {
      return null;
    }

    return fromBase94(message);
  }

  serverPoll(): [ClientId, Uint8Array] | null {
    const message = serverMailbox.shift();
    if (message == null) return null;
    return [message.clientId, fromBase94(message.data)];
  }
}
