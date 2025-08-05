# Tuesday 5 Aug 2025

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

Now adding a spring to the camera to follow the player. Added a generic spring to the prism package.

The camera is so smooooooth I LOVE IT. It feels good just to move the character. Getting real excited now, I'm starting to feel like this could have potential. Somehow it feels much more responsive than the Godot version, not sure if it's because of the frame rate or what.

## Cursor weirdness

So there's something weird going on with the cursor snapping to tile coords when going negative. I presume it's something to do with the f32 -> i32 truncation behaving differently when negative.

```odin
	a: f32 = 1.2
	b: f32 = 1.8
	trace("0.2=%d, 0.8=%d, -0.2=%d, -0.8=%d", i32(a), i32(b), i32(-a), i32(-b))
```

This returns `0.2=1, 0.8=1, -0.2=-1, -0.8=-1`

So yes, looks like it always floors, what I really want is to floor towards zero.

Ok after a stint with Claude code that couldn't figure it out, it was actually much simpler. Just needed to do a `floor(x)`, even though I thought the int conversion would do that already. I suppose it doesn't even though the above trace indicates it would...

Ah yep, I was just reading it wrong.

```odin
a: f32 = 1.2
	b: f32 = 1.8
	trace(
		"1.2=%d, 1.8=%d, -1.2=%d, -1.8=%d, floor(-1.2)=%d, floor(-1.8)=%d",
		i32(a),
		i32(b),
		i32(-a),
		i32(-b),
		i32(math.floor(-a)),
		i32(math.floor(-b)),
	)
```

Outputs: `1.2=1, 1.8=1, -1.2=-1, -1.8=-1, floor(-1.2)=-2, floor(-1.8)=-2`

Ok really should get to bed.... too much fun. Maybe I'll just get a few walls rendering first

First thing tomorrow should be fun - procgen rooms and Djikstra pathfinding.

Also need to work out why cursor is missing when net delay is removed, probably player map is not populated on one client.

# Wednesday 6 Aug 2025

Ok first thing I'm gonna start on procgen because it's fun.
