### Tuesday 5 Aug 2025

Break: Finish making inputs depend on mouse cursor pos, or perhaps add a key to switch between instances. Probably cursor pos is best for now.

Adding mouse tile cursor and then I'll start on procgen

Mouse cursor done, but now I realised I need to make local command work before it's confirmed by the server (and probably render it out)

Actually first going to add zoom

Time to fix local command

Idea: Server sends an event sequence number with every event. The client then sends the most recently received sequence number to the server in a SubmitCommand message. This way, the server can ignore commands that were initiated _before_ the server cancelled the player command.

Example:

- Server sends player join event (seq-01)
- Client sends SubmitCommand to move to [1, 0] (seq-01)
- Client sends SubmitCommand to move to [2, 0] (seq-01)
- Server receives first SubmitCommand to [1, 0] and as a result, cancels the player's commands. Sends a command update event (seq-02).
- Server receives second SubmitCommand, but ignores it because it's (seq-01)
- Player issues another command to move back to [0, 0]
- Server receives second SubmitCommand, and allows it because it's (seq-02)

That doesn't solve the problem of how and when to clear the local event though. Perhaps an equality check would just work?

- If local and server state are equal, then clear local state
- If server sends a command update event that has a _server override_ flag, then clear local state

I think the only robust way to solve the second problem is with another sequence number. The client entity should increment its command sequence number, and the server should send the client's sequence number in a CommandChanged event.

Second problem seems fairly solved with that sequence number. I'll revisit the server sequence number again in future when it's needed.
