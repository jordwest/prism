import { ClientId, HostNetPeer, ClientNetPeer } from "./interface";
import { toBase94, fromBase94, Base94EncodedString } from "../base94";

type Mailbox = Base94EncodedString[];
type ServerMailbox = {
  clientId: ClientId;
  data: Base94EncodedString;
}[];

type SocketServerMessage =
  | { type: 'RoomHosted', connection_path: string }
  | { type: 'Welcome', your_client_id: number }
  | { type: 'ClientConnected', client_id: number }
  | { type: 'RelayedMessage', client_id: number, message: string }
  | { type: 'Ping' }

type SocketClientMessage =
  | { type: 'HostRoom' }
  | { type: 'Hello' }
  | { type: 'SendMessage', to_client_id: number, message: String }
  | { type: 'BroadcastMessage', message: string }
  | { type: 'Pong' }

/**
 * Doesn't send messages anywhere, just for running multiple instances in a single tab
 */
export class WebSocketRelayHostNetPeer implements HostNetPeer {
  _socket: WebSocket | null = null;
  _rootPath: string;
  _serverMailbox: ServerMailbox = [];

  connectionPath: string | null = null;

  _isListening: boolean = false;

  clientConnectedHandler: ((clientId: ClientId) => void) | null = null;
  listeningHandler: ((connectionPath: string) => void) | null = null;

  constructor(rootPath: string) {
    this._rootPath = rootPath;
  }

  isListening(): boolean {
    return this._isListening;
  }

  _send(socketClientMsg: SocketClientMessage) {
    if (this._socket == null) {
      throw new Error("Host socket not open");
    }

    this._socket.send(JSON.stringify(socketClientMsg));
  }

  listen() {
    const socket = new WebSocket(`${this._rootPath}/host`);
    this._socket = socket;
    socket.addEventListener('open', () => {
      console.log("Hosting room")
      const msg: SocketClientMessage = {
        type: 'HostRoom'
      };
      socket.send(JSON.stringify(msg));
    })
    socket.addEventListener('message', evt => {
      const msg = JSON.parse(evt.data) as SocketServerMessage;
      if (msg.type === 'RoomHosted') {
        this.connectionPath = `${this._rootPath}${msg.connection_path}`;
        this._isListening = true;
        this.listeningHandler?.(this.connectionPath);
      }
      if (msg.type === 'Welcome') {
        if (msg.your_client_id != 1) {
          throw new Error("Host should always be client ID=1")
        }
      }
      if (msg.type === 'ClientConnected') {
        this.clientConnectedHandler?.(msg.client_id as ClientId);
      }
      if (msg.type === 'RelayedMessage') {
        this._serverMailbox.push({ clientId: msg.client_id as ClientId, data: msg.message as Base94EncodedString });
      }
      if (msg.type === 'Ping') {
        this._send({ type: 'Pong' })
      }
    })
  }

  onClientConnected(handler: (clientId: ClientId) => void): void {
    this.clientConnectedHandler = handler;
  }


  onListening(handler: (connectionPath: string) => void): void {
    this.listeningHandler = handler;
  }

  send(clientId: ClientId, message: Uint8Array): boolean {
    this._send({ type: 'SendMessage', to_client_id: clientId, message: toBase94(message) });
    return true;
  }

  broadcast(message: Uint8Array): void {
    this._send({ type: 'BroadcastMessage', message: toBase94(message) });
  }

  poll(): [ClientId, Uint8Array] | null {
    const message = this._serverMailbox.shift();
    if (message == null) return null;
    return [message.clientId, fromBase94(message.data)];
  }
}

export class WebSocketRelayClientNetPeer implements ClientNetPeer {
  _clientId: ClientId | null = null;
  _connected: boolean = false;
  _socket: WebSocket | null = null;
  _mailbox: Mailbox = [];

  _connectionPath: string | null = null;

  constructor() {
  }

  isConnected() {
    return this._connected;
  }

  _send(socketClientMsg: SocketClientMessage) {
    if (this._socket == null) {
      throw new Error("Client socket not open");
    }

    this._socket.send(JSON.stringify(socketClientMsg));
  }

  connect(connectionPath: string): number | null {
    console.info('connecting to', connectionPath);
    const socket = new WebSocket(connectionPath);
    this._socket = socket;
    socket.addEventListener('open', () => {
      this._send({
        type: 'Hello',
      })
    });
    socket.addEventListener('message', evt => {
      const msg = JSON.parse(evt.data) as SocketServerMessage;
      if (msg.type === 'RoomHosted') {
        throw new Error("Unexpected RoomHosted message")
      }
      if (msg.type === 'Welcome') {
        console.log("Welcome, client ", msg.your_client_id)
        this._clientId = msg.your_client_id as ClientId;
        this._connected = true;
      }
      if (msg.type === 'ClientConnected') {
        // Only the host handles this event
      }
      if (msg.type === 'RelayedMessage') {
        this._mailbox.push(msg.message as Base94EncodedString);
      }
      if (msg.type === 'Ping') {
        this._send({ type: 'Pong' })
      }
    });

    return null
  }

  send(message: Uint8Array): void {
    // if (this._isHost && this._clientId != null) {
    //   // Module is sending to itself, skip going over the wire
    //   this._serverMailbox.push({ clientId: this._clientId, data: toBase94(message) });
    //   return;
    // }

    this._send({ type: 'SendMessage', to_client_id: 1, message: toBase94(message) });
  }

  poll(): Uint8Array | null {
    if (this._clientId == null) return null;

    const message = this._mailbox.shift();
    if (message == null) {
      return null;
    }

    return fromBase94(message);
  }
}
