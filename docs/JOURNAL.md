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

# Friday 8 Aug 2025

Ok so today I watched [a video](https://www.youtube.com/watch?v=MEZoKKAoUAU) that sparked an idea - why not simulate the game state completely on every client? From tile generation to monster spawning to pathfinding... it can simply be simulated deterministically on every client and then the only thing that needs to be synced between clients are the player inputs. It would simplify things so much, no more serializing game events, only player inputs (and player join/leave events/mouse cursors).

Ok that took 3h but I think totally worth it, and knocked off the issue with replaying state to newly joined clients. The network consumption is also down _hugely_. This means catching up is likely to be CPU bound rather than network bound, so probably can happen super quickly.

Wow, 59 hours tracked in the past 7 days... crazy. I don't think I've every worked so much on a project in my life.

Listening to [this](https://www.youtube.com/watch?v=_ie639ilKW8) after listening to Jayasara's Rumi reading, and thinking this kind of music would really fit with the theme of the game. Perhaps it could be about diving deep in a desert dungeon to discover hidden parts of yourself, and the twist at the end could be discovering that all the characters you've played are the same all-knowing one.

Next thing is I'm getting these errors when moving the character quickly before the second client start up:

```
[INS:1]  Error reported at
client.odin:31:client_tick
client.odin:128:client_poll

UnexpectedSeqId{expected = 0, actual = 14}
```

I guess the server is sending any updates immediately before the client has sent off the identify command. Yep, fixed.

Finally, time to start working on gameplay mechanics again. Player pathfinding is first, although I kinda want to start getting combat going. Ah might as well do pathfinding since the djikstra stuff is still fresh on my mind. Gosh it's going to be so much easier not having to serialize all the entity data like HP etc.

Just had a thought that it's pretty important to not do any framerate dependent changes to game state, like for example iterating djikstra maps a certain number of times per frame, since the map could potentially end up with a different number of iterations depending on framerate. Would be fine if it does it but also always requires a certain number of iterations before evaluating the map.

Next need to add mouse button events, to differentiate from mouse move.

Thinking about how to do the turn system. So first I'm pretty sure I just need to check only when a new log entry occurs. Otherwise not necessary.

Each evaluation, we first need to check if any players have actions points available _or_ have an active command. Then if the command can't be executed, it gets cancelled.

If all players have been evaluated and have no more action points or no commands, then:
1. NPCs are executed
2. Action points are added to all players

Turn system works well.

Tomorrow: Add a delay between turns. To do this, I'm gonna need to push log entries onto a queue for processing, then pull them off in the tick function to ensure they're still replayed deterministically. The tick function also means I can remove the loop and the `turn_evaluate_all` function. Instead, just call turn_evaluate when either:
 - There's a new log entry in the queue
 - It has been more than 0.25 seconds since the last turn was completed

 Now I'm realising a problem with this setup. What if the player wants to interrupt movement while the animation is happening? If events are queued and played until the next event is received, it's impossible.

 The solution I can think of right now is to have the host trigger end of turn events, which it forwards to clients and those clients then process the turn. That way if the server receives a new entry, it will appear in the queue before the turn event that executes the movement. Nearly 12 hours today, time for bed...

# Saturday 9 Aug 2025

It's 11:30pm and I'm starting... spent 6 hours playing with an isometric renderer idea.

Going to add turn progressing events. Hmm that was easier than I thought it would be... I guess the sleepless night thinking about it last night helped...

I do need to add command cancellation actually, might do that and test. Pretty easy.

# Sunday 10 Aug 2025

Today the plan is to make sure obstacle entities can't move on top of each other, then finally add some enemies. Excited about finally getting some gameplay going and being able to actually play it.

So first up I need to check each location before moving an entity into it. I suppose it probably makes sense to do the allied entity swap thing too at the same time. And the derived state thing.

Derived state now lives in its own struct, now need to calculate entities for each tile.

Ok so I've got the calculations, but now I need to check when running the move command whether an entity needs to be swapped. And the follow command complicates things a bit, because it shouldn't swap with the followed entity. I'm actually starting to think that maybe follow should actually just follow the nearest player, not a specific player.

Thinking now though I should copy across the entity's flags instead of always accessing them through the meta info, since they may change over the life of that entity. Worth doing that now before I have to change it in too many places.

All that is now done. Ally position swapping, tile entity lookup, copying across flags. Only thing is I've removed follow for now. I need to think about that some more, likely going to just do a follow-nearest-ally instead.

Next up, finally, is enemies. I think after some basic enemies that might be it for the day though, trying to take it easy over the next couple days.

Another though re swapping: Should only one swap per turn be allowed? Otherwise it could allow for some cheesing of attacks.

Ok next up, enemies! Should be fairly easy now actually, as so many of the needed pieces are in place. Need to:
 - Add sprite - done

Caught up on a bit of a side mission - getting increased move costs through water to work. Got that working.

Thinking also about how to properly delay things... when attacking there needs to be a delay between each enemy attack so they're visible, not just a delay after each turn. The host should be in sync with this delay too so that actions can be cancelled before they happen. I don't think this is too hard, a command can just return .OkDelay when executed, and the turn system can flag that it needs to rerun again after a delay.

Maybe I'll do that after I've added enemies and attacks.

 - Spawn entity - done

Had this thought that for avoiding enemies, I could add a gaussian over the djikstra map around enemies. That way the pathfinding would naturally route around them. I think it could work.

 - Add hitpoints - done
 - Render hitpoints in debug - done
 - Handle attack command - done
 - Trigger attack when moving onto non-allied entity - done
 - Handle entity death - done

Think that's enough for today. Tomorrow:

 - Render hitpoints box
 - Spawn many entities scattered around
 - Enemy AI

# Monday 11 Aug 2025

 - Render hitpoints box - done
 - Spawn many entities scattered around - done
 - Enemy AI - next

So I've been thinking about how to decrease djikstra generation, because the way things are right now it gets regenerated every time an enemy moves which is causing huge frame drops with only a handful of enemies.

What I realised is that ideally, the djikstra map shouldn't take into account any objects that move, because the object is likely to have moved by the time we get to it anyway. The issue is in when the object is in the space we want to move in _immediately_. But I think that can be solved fairly easily. Just look around for other spaces where the move cost decreases.

There's another special case where a row of entities that are keeping their distance from the player could block access to enemies behind that are advancing toward the player. I think this could probably just be solved by making the enemy wander if it has no path, but this can be solved if I ever get to it.

The other option could be to allow enemies to also swap places with each other... But this could really change the balance of the game a lot and be difficult to see what's going on.

So I think this is all going to need a bit of a refactor of the way I calculate djikstra maps. I've had an idea floating around for a bit where I have a struct that defines the input parameters for the map, then just pass that struct in wherever a map is needed and the system checks whether its been constructed yet or not, and if not, constructs it and returns it.

Also going to need to implement a key to switch between debug views of the different maps, that should help a lot with diagnosing issues here. Think I'll do that first. Ok that's done. Now to refactor these maps.

Just need to try with a few more instances now. So I'm getting that crash when attempting to print a trace again. I'm starting to wonder if its a bug in odin, but more likely it is a bug in my code somewhere. I suspect I'm ignoring an allocation failure somewhere, although it's hard to image what would be allocating that shouldn't...

Actually maybe a good idea would be to put in a catch-all allocator as default that always panics, so that only temporary allocations succeed.

Oooohhh k that was a massive tangent. So I think some memory was overflowing the arena... it seems I was likely writing to the frame arena when it was already full... and then that was writing into the trace area. Adding some 1kb padding around the trace seems to have protected it from stray game state breakages, and I've added some code to validate

Ugh I think this might actually be a bug in the odin stdlib. I might need to work around it by calling a non string-building error/warning function for non-trace messages. Like just pass an int with the error id and any associated data in a struct.

Ok using `bprintf` seems to have fixed it for now... it seems like there's something weird going on with tprintf. Might pop up again but maybe I'll just call this solved for now and leave the memory validation code in for now.

Going to need to go through the code and find all the instance of tprintf and replace them.

All done, annnd it's 2am and I'm playing with pathfinding again. It's all a bit weird when dealing with obstacles, but I think I'm close to having something workable. Good news is I haven't seen any more crashes since locking down all the memory. Think that's enough for tonight...

Just came across [this on Roguebasin](https://www.roguebasin.com/index.php/The_Incredible_Power_of_Dijkstra_Maps):

> Treat monsters that haven't moved since last turn as obstacles

Brilliant. This is much better than the CanMove flag, since it should automatically capture monsters (and players!) that aren't doing anything and route around them. If a monster is sitting in one place fighting, it should be treated as an obstacle.

# Tuesday 12 Aug 2025

Today:
 - Enemy attacks - done

Ugh memory issue is back again... Going to try checking the memory being used by trace. The weird thing is that changing my code causes the issue to go away, it's like some memory alignment issue or something.

I guess ideally I'll just remove all the cases of printf, but that's going to be tough when building the UI. Although perhaps it's mostly the formatting args that are causing issues.

Could also try to track down the bug in Odin... but I've already looked at that code and it's pretty tough to follow.

Anyway enemy AI is done now, at least basic hit/miss chances.

 - Hit/miss chance - done
 - Hit damage indicators
 - Add fire or items or something interesting to gameplay

I'm wondering if the memory issues may be due to the maps and the way I'm iterating them. Could that be introducing some overflow. OMG I think I found the issue. The entities and players maps were being initialised twice - once by host and once by client. That would definitely cause weirdness if there's some pointer lookup going on. I still don't understand quite how that would cause issues in the printfs, but I guess all kinds of weird things can happen when pointers are invalidated. Also it was usually in the trace function that logged an entity id where the crash happened. Let's see how it goes. This realisation happened when I walked away from the computer... gotta do more of that... It really feels like stepping away lets the universe take care of it... So relevant to my convo with Jo last night.

God nope it's still crashing.......................... fuck

Could it be clay??? There is an out of bounds error there too....

Ok so I think I've tracked it down... There's a _user_formatters pointer that is nil when the app starts up, but then it changes to a different number right before the crash.

So it seems the fmt_arg function is trying to access that, assuming it's a slice, but it's actually just a bad pointer. So something is overwriting that memory, and now I'm looking at the pointer locations and it seem clay might be the culprit since it's near the end of the app memory, and right before the location of the _user_formatters pointer pointer.

So, let's see if disabling clay fixes it...

Ok user formatter point is still changing to 1, but it's not causing a crash... that's weird... Ah I was still creating the clay arena. Just not doing anything with it.

Ok, clay is not the culprit.

Omg. Found this in the clay commits for August... I knew I should have just tried updating lol

```
		// NOTE(laytan): Put the stack first in the memory,
		// causing a stack overflow to error immediately instead of corrupting globals.
		link_flags = gb_string_appendc(link_flags, "--stack-first ");
		// NOTE(laytan): default stack size is 64KiB, up to a more reasonable 1MiB.
		link_flags = gb_string_appendc(link_flags, "-z stack-size=1048576 ");
````

That's almost certainly it. It seems like a stack overflow happens right in a specific place and that's why it always fails with the AI. 64kB is wayyy to small. That's almost certainly it.

God, pretty sure that was it HA. Should have just installed the new version, although it was a fun and interesting exploration of the odin source. Also have a better understanding of the memory layout etc.
