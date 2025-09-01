export type ClientId = number & { _clientId: never };

export interface HostNetPeer {
  connectionPath: string | null;
  listen(): void;
  send(clientId: number, message: Uint8Array): boolean;
  broadcast(message: Uint8Array): void;
  poll(): [ClientId, Uint8Array] | null;

  onClientConnected(handler: (clientId: number) => void): void;
  onListening(handler: (connectionPath: string) => void): void;
  isListening(): boolean;
}

export interface ClientNetPeer {
  connect(path: string): number | null;
  send(message: Uint8Array): void;
  poll(): Uint8Array | null;

  isConnected(): boolean;
}
