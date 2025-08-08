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

Got tile data struct in place, also tweaked the cursor a bit. Now to draw rooms and render them.

Thinking I'll also add a switch to toggle between rendering host and client state (but keep using client state for things like camera pos)

Switch is done, added some deterministic randomness thanks to splitmix, got a room rendering. Now need to add more rooms. Getting a bit ahead of myself thinking about all the things I added in the last rewrite such as doors.

I think first thing is to find a place to put another room along the wall of any previous rooms.

Now need to detect overlaps, writing an aabb check.

a.x1 <= b.x1 && a.x2 >= b.x1
```
       x1     x2
A:      |------|
B:           |-------|

A:      |--------------|
B:           |-------|
```


b.x1 <= a.x1 && b.x2 >= a.x1
```
A:               |------|
B:           |-------|

A:               |------|
B:           |-------------|
```

!(b.x1 < a.x1 && b.x2 > a.x1)
!(a.x1 < b.x1 && a.x2 > b.x1)
```
A:               |------|
B:     |------|

A:      |------|
B:                |------|
```


Room generation done to a good enough standard for now. Can tweak the dead ends issue later when there's some actual gameplay (added a todo)

Really feel like I'm hitting the flow in Odin now, haven't hit many roadblocks the last few days. Even allocation is pretty much a non-issue now. The hot reload dev cycle is also just _so_ nice.

Next need to reenable iteration on the djikstra map, host.odin:22 and hopefully start to visualise it

Djikstra map is working, but the issue I'm running into now is that reevaluating tiles for higher cost adds a lot of iterations.

I think maybe the solution will be to only calculate that when totally necessary, in general it's not going to be calculated every frame anyway. Even with cursor pathing, it only needs to be calculated once when the player or any entity moves, then moving the mouse can just trace the path back on the existing djikstra map.

Some creatures might be dumb anyway and head straight for the player, ignoring traps etc.

Perhaps A* would be more effective for the smarter enemies.

I think it's actually gonna be just fine without the reevaluation. I'm reevaluating neighbours at least, just not adding them to the queue again. This works for small cost multiples (like 2x) on small regions of high cost. It works less well on multiples of 5x with large eg bodies of water. But I think this should still be plenty good enough for now.

Ok think I'm gonna have to call it there for the night. Gonna call djikstra maps done. Tomorrow will be fixing the client/server state synchronization, sending tiles to the client, and maybe pathfinding player movement.

Might also try out creating a spawn point, and pathing to the furthest point on the map then regenerating another djikstra's map.

Ok that last bit is done, can't stop...

Had this idea for what to do when a player dies. They could resurrect as a ghost, which has a few totally different strengths and weaknesses:

 - Players can't see their ghost vision (and maybe can't see the ghost itself?)
 - Can induce fear into players and enemies by passing through them
 - Can move very quickly
 - Can go through walls
 - Can affect psychic abilities/enemies
 - Infinite HP (but teammates may stay alive)
 - Can't carry items - upgrades abilities instead
    - Telekenesis? Can hurl items around the room
 - Generally a pretty weak character on its own but should still act as a good support for the team (or cause chaos)

# Thursday 7 Aug 2025

First thing I think I'll work on is consolidating event handlers between server/client as I think this is going to be get more challenging the longer I leave it.

Done and also improved error handling, much easier to see what's going on now when errors and their locations are well reported. Not quite as good as a proper debugger but good enough for now.

Next up is sending the tile data to the client. This might involve some generic array serialization.

So many tangents... I think I've got serialization working (but not deserialization), but that led to writing a unit test runner, and now trying to implement a basic version of the runner in rust to see if the serialization tests will pass. This whole project is bringing together so many things I've been thinking about for a long time and it's very exciting.
