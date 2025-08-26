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
 - Can bless or curse items. For example - 20% chance to bless, 10% chance to curse. If it fails, the curse % goes up the next time (eg 20% bless, 20% curse).
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

#lore Listening to [this](https://www.youtube.com/watch?v=_ie639ilKW8) after listening to Jayasara's Rumi reading, and thinking this kind of music would really fit with the theme of the game. Perhaps it could be about diving deep in a desert dungeon to discover hidden parts of yourself, and the twist at the end could be discovering that all the characters you've played are the same all-knowing one.

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

Ok now that that's out of the way I can get back to the good stuff.

 - Hit damage indicators - done
 - Add fire or items or something interesting to gameplay

Ok I'm pretty much back to the C# version in terms of gameplay now... 2 weeks later. Now finally, adding new features heh.

It's funny, it's like there suddenly more of a creative block, a fear in the chest. The rewrite was easy comparatively, because the task was fully known. This, now, is unknown. It's a complete mystery, and there's a hesitance to take a step because of the sheer, vast array of possibilities. I think that might be why modders do so well - they start from a known base and just add ideas as they come up with them. For me, I guess in a way I'm basing this off brogue, pixel dungeon, as well as zombicide and catacylsm. So there are plenty of ideas there, just gotta start. Maybe I should write down a bunch first:

 - Fire potions
 - Teleportation
 - Poison
 - Room with rope bridge
 - Fog of war - done

Got basic fog of war working, still need to darken areas that have been explored but are no longer in vision range, but this will do the job for now. Next up I'm kinda keen to work on the rope bridge room... could be fun to add fire to that.

And with that... I think I'm going to call the milestone b3 Odin rewrite DONE. And move on to b4, content.

Ok so I'm working on improving the djikstra maps, but they're not being refreshed except when an allied player moves. I need to refresh them all when the turn ends, so routing around stuck enemies works.

Ok I think what I've got now is working pretty well. Slight extra cost (50) for moving onto moving obstacles, and blocked completely by non-moving entities. Good enough for now. Oh also need to exclude tiles that haven't been seen from the player generated maps.

Djikstra for player now also only calculates in seen areas.

Ok so my aabb needs complete reworking. It should have a width and height instead of x2 and y2, since that's kinda ambiguous. I'm thinkin what I should do instead is just create a new `Rect` type and deprecate the `Aabb`, then just...
Ok after chatting with Claude, it suggests keeping x2, y2 but making them _exclusive_ bounds as that's convention, and simplifies checks. So that's a fairly minor change. It does suggest naming it Rect instead of Aabb though.

Got a pit island and rope bridge up, so cool. I think I want to work on fire next, make the world feel a bit more dynamic. Looking forward to making things feeling a bit more.. unpredictable.

Ok damn it's really starting to come together now. Playing with it on iphone and even in Safari it feels very smooth. A proper iOS build might really be feasible...

Tomorrow I think I want to work on getting fire going, and then I can think about adding items, starting with a potion of fire.

# Wednesday 13 Aug 2025

Got a really nice tooltip system working with Clay. Clay is frikking awesome. Damn Nic has really outdone himself.

Fire is working, firebugs work. This is just awesome. It really feels like this is what I'm meant to be doing. Haven't had flow like this in a big project in a loooong time, maybe ever. I just can't put it down.

So now a couple things that I've been putting off keeping niggling at me:

 - Sprite animations, and replacing the sprite coords with a more fleshed out struct of sprite information (allowing animation frames etc)
 - Proper turn handling. The queue and all that, and probably moving a bunch of logic out into "events" that get queued up. The idea being that an incoming message triggers an event on the event queue, then that triggers more events. All events should be processed _before_ pulling another message off the message queue. That way timing should all be completely deterministic.

I think I'll start with the sprite animations because I want to get fire going. Then need to add entity hurt events that are triggered by fire effects on the tile -- this is why I want to refactor turn handling.

Ok that's done, at least enough to get things working for now. Now to tackle this event system. This is gonna be ripping a bunch of stuff apart. Might actually start a branch for this.

Ok events are done, although I opted to skip making a queue for that for now. Events are fired immediately. I'll add the queue when I need to schedule events for later, if ever.

However now it seems multiplayer is broken. There was a race condition before, so perhaps this has just revealed it. Going to see if I can get to the bottom of it.

Ok I think it's probably something to do with the procgen. I think procgen should be a log event, so it doesn't proceed beyond it until the procgen is done. Also maybe players should all join _before_ procgen happens. Player placement depends on procgen, and if the entity is created before the level is ready, there won't be anywhere to place them. So yeah for now, I think I'll add a start button or something that fires off a log entry with the game seed, triggering procgen on each client.

So first thing I need to do is make the web runner actually emulate "listen" and "connect".

Ok think that's all fixed now. I thought I saw a desync at one point, but haven't been able to make it pop up again. I think for now I'll leave a second instance up as a spectator, just to see if I can find any more desyncs like that.

Ok I think I've caught one. It could have been while going through the doorway, something to do with pathing.

It would be so handy to be able to rewind to diagnose... and I don't think it would even be that hard to implement especially since the log entry store is already a thing. Yeah this is going to be really difficult to diagnose without a replay thing. Doesn't have to be all that fancy, just store the log and then replay step by step.

Seems like it's more an issue when there are multiple players. I wonder if the order of iteration of players is the problem, or of their commands or something. Anyway, something to look into tomorrow.

I have a suspicion that the issue could be in the djikstra generation, it could be non-deterministic if one is triggered before the other. I'm not sure how that could happen except in the render pipeline, although actually... it does generate it for the mouse cursor too...... Hmmm. That could actually be it. Although I would think the map should be fairly stable. It only uses the MovedLastTurn flag, which should be the same across all clients. Either way, it seems to have something to do with the player pathing failing on one client and not the other. I bet even a replay wouldn't catch that, actually.

Ok I think I may have fixed it... just by removing djikstra generation from the case where its used in rendering. That does mean the path visualisation has disappeared, but that's an easy fix. Just generate the paths for every player after they move.

Yeah that seems to have fixed it. It does feel a bit brittle, but I'm sure I'll get better at separating out the deterministic stuff as I go. For now the benefits farrrr outweight the costs, game logic is so much easier to follow.

Just had a thought that maybe djikstra maps used for player input and rendering should just be generated separately. Other ones are generated at set times instead of on demand, since on demand introduces a lot more potential for race conditions.

Hmm now I have an issue where the players djikstra maps aren't regenerated (or aren't regenerated properly) when an enemy dies and is blocking a door. It should regenerate immediately after the entity dies, yet somehow that tile still blocks the algorithm (or the algorithm isn't running for some reason)

Ok that's fixed too I think! Just needed to clear them out. Yeah this whole on demand generation thing isn't working so well, I think I'm going to just regenerate them at set times, easier to keep track of ordering and everything.

Also -- why aren't the paths being rendered anymore? Only to the cursor, but not to the current action. I think that whole derived thing might need rewriting... Ok yep that's fixed now too. Just keep winning.

So tomorrow:
 - Remove on demand djikstra generation, instead just return nothing if the map doesn't exist
 - Generate a set of maps after certain events. Consider splitting it up over frames, although probably not necessary
 - Items? Fire potions? Different weapons?
 - Lobby and connect button

# Thursday 14 Aug 2025

So maybe the replay system at this point is a bit overkill, however it could be good to at least let the client pause processing of events and have a key that steps through. That way I can do something kinda like step through debugging when an issue crops up. Then the replay system would just involve saving the moves and reloading them (actually, maybe I just have the host save the moves anyway, and when an issue pops up I can implement the replay system? eh still probs too much work at this stage)

Ok so stepping is implemented and I've already found a bug. Somehow the players jump forward like 4 tiles when contesting a doorway.

Sooo somehow, the player is getting like 500 AP for some reason. Ah... I bet its the cost thing. Although, that is returning if it's 0 or less...

Ok so somehow, the turn is advancing when it shouldn't be. The player has no command, so it should be returning early.

Ok I think I might know what's happening. turn_evaluate_all is called after each command, so here's the timeline:

1. Player issues move command
2. Player moves, but cannot move anymore this turn
3. Other player moves, then cannot move anymore this turn
4. First somehow player issues another move command while turn is incomplete
5. Turn is marked as "complete", but the end turn event isn't yet queued up
6. End turn event is queued up
7. Player command is processed, and evaluates turn_evaluate_all, which says the turn is incomplete and issues another turn complete command
8. End turn event is processed

So really what I think is needed is for the turn_evaluate_all to exit if the turn is already complete. Thing is that turn_complete is being used as a latch to test if the turn completion has been sent off yet or not. So I think I need two flags here, one used for turn_complete (as currently) which prevents turn evaluation, and another to check if the turn has been sent off yet and avoid double-sends.

Then, when a turn log entry is received, reset both of these flags.

Ok that seems to have fixed it.

So now I'm trying to get replays working properly, because there's actually an issue when playing back a set of events. It seems like playing them all very quickly has some different effects.

Ok yep playing back through but _stepping_ through makes the replay work perfectly. So there's some kind of frame dependent weirdness going on. Actually good that I ended up doing this replay thing or I probably wouldn't have discovered this issue.

Ah, I think I might know what it is. There are some calcs happening each frame, but if there are 2 or more events sitting in the queue, they'll both get processed but the frame events will only get processed once. So I guess maybe I should move those events out of frame handlers and into event handlers instead. But also I might first test to see if limiting log entry processing to once per frame fixes things.

Ohhhh shit it's actually because I'm pulling things off the queue and then returning, so events are getting lost completely. God I'm dumb. Ooooh k yep that has really fixed things.

Yep replays are working quite consistently now which is nice! Time for more content *rubs hands*

Added some little grass sprites. I'm thinking I'll use the same frame things for animation for sprite variations for now.

Ok what's next.. I think maybe some more content. Would be good to start adding items, maybe a potion of healing to make the level last longer. Also want to then play with that and experiment ways to heal that don't involve sitting and resting, which wouldn't play well with multiplayer. Unless, I do some kind of campfire thing where you only get a limited number, and everyone in a vicinity can heal by it. Or just skip that entirely and have some kind of well of life, where everybody can take a shot from it.

Also would be cool to add some buttons where all players have to stand on them to unlock a door together. Or there are mechanisms with two buttons for three players, and one button for two players. Only one player can go through the door (and there may be enemies!). Maybe other doors close down at the same time.

Thinking now about how to ignite things properly. Looping through the array and setting surrounding tiles on fire doesn't work because if they're in the positive x, y direction, they'll spead instantly on the same turn.

What I think I need is an Igniting flag that gets set, then the first actually starts on the next turn. Alternatively, I can set the turn on which the fire started, and then don't spread if it's the current turn.

Ah yes that seems to have fixed the problem.

I think it might be time to bite the bullet and start on the item and inventory system. Can start out without a UI for now, just something simple that logs to console. Although maybe that's a waste of effort... it wouldn't even be that hard to display a non-scrolling list of items with clay. Also it would feel really motivating to have a UI that feels responsive to use.

Ok so the first item will be a healing potion, I need to flesh out the data structures for this thing.

Should individual items have their own data? I guess they might, be I think I can just use the same pattern as I've used for entities + meta. The meta can either copy across or just be a pointer. Actually yeah, certain items might have upgrades and not stack together.

Interestingly today it feels like that obsessive, intense energy has gone, and left the usual kind of emptiness in the chest. There's still a pull towards working on this, but it doesn't have that same energy as before. It's like now the project is feeling pretty good, and there's a mild fear of going further on it because of the overwhelming size of the possibilities ahead. I think I'll just take more breaks, but still keen to keep working on it, still so many ideas for things to add. Also I think once I have an inventory system, just creating items and creatures will start to really fill out the world.

It's like a feeling of worry... pure worry, in the chest. Just not towards or about anything, although some things pop into the mind, it just feels like, afraid. That I'm not going to be ok.

### Container system

So I'm thinking about how to have entities *and* tiles contain multiple items, without the memory usage absolutely blowing up. I think the idea that feels most right right now is to put all items in a big generational arena like with entities (or at least how entities will be, or just using a map), then each item can have a "contained by" (which is a union of tile pos, entity, or another item). Then, whenever that value is changed, recalculate all the containers and attach their ids to a linked list that has the item/tile/entity as a key. If that's all stored in an arena, then the arena can just be reset before doing the recalculation, easy.

Ok so I think that's all working as expected. I've got potions appearing on the map, just need to be able to pick them up now. That's a new command which should trigger a pick up item event.

Picking up is done, works pretty well. Now to just draw some rudimentary inventory UI.

Ok so super basic inventory UI is working. Now I need to get it to be clickable... it's time to actually look deeper into mouse interaction in clay. I had mouseover events working before, but the challenge now is that I need to filter UI events out from interacting with the game board.

#lore #idea: have a "Reincarnate" button instead of respawn. Leave little notes/clues around or inscriptions on the wall that suggest many have been on this same path. The "Grail of Temula" (Temula is amulet backwards).

Ok I'm getting a bit slow now, maybe burnout setting in. I'm going to just check out how I might do the UI mouse interaction so I can mull over it overnight.

# Friday 15 Aug 2025

Today was a pretty slow day compared to the past two weeks. I needed to just sit and rest for most of the day. Lots of stuff coming up and it feels like the body just needs to rest.

I did get animation delays working this morning, as well as almost being able to consume potions, however it's now freezing up when clicking the item in the inventory.

Ok now suddenly it's working again for some reason.

# Monday 18 Aug 2025

Thinking about loot sharing. Some ideas:

### Gold only
You only collect gold on each floor, not items. Each player gets this gold. Then, at the end of the floor, all players can access the shop where they can choose from a limited set of items (different for each player but using the same loot table). This is similar to how Noita works (although it also has lootable wands)

### Consumables are duplicated
Another idea - consumables are given to each player when collected. If I pick up a health potion, every player gets a health potion. This feels a bit unrealistic and awkward to me.

### Shared consumables
All consumables go into a shared pool and can be used by any player at any time.

### Combined

I'm leaning towards something like:
 - The level contains mostly mundane loot - unenchanted level 1 weapons which can be upgraded, but are not an exciting find in and of themselves.
 - Picking up items makes them go into a shared loot pool. A player can also directly equip an item, but cannot carry it in their own inventory otherwise.
 - Purchased items are "owned" by the player who purchased it. Only they can use it, but they can choose to release ownership.

So shared inventory, equally distributed gold collection, individual equipment.

A shared loot pool also means all players are more likely to die together, eg when running out of health potions. Gold can then supplement the found loot and be used to purchase upgrades at the shop.

I think if there's plenty of mundane loot on each level, there should be more than enough to go around. The real exciting loot would appear in the shop or in the special per-player loot rooms.

Create resurrection potion by combining three health potions - this means everyone can keep playing but the loss of three potions significantly reduces the survivability of the team. Sort of a way of reducing the health pool of the team when a teammate dies, but still an interesting decision that the team must make (and be careful not to anger the dead player's ghost).

# Tuesday 19 Aug 2025

Dentist visit today got some interesting feelings going. Working on selecting which action to take with a potion. Got consuming working, and buttons for throwing and dropping that don't yet do anything. Drop should be the easy one, but I guess I might as well do both at the same time since they'll each need commands.

Throwing is implemented but now I need to add the UI for targetting. Also need to think about how to store that mode information in the state - should it be a generic "targetting" mode (probably) that has information about what will happen when targetting is done? That seems to make the most sense.

But now I think I need to go sit for a bit.

# Saturday 23 Aug 2025

After a bit of a side quest in building my own music tracker, I'm back to motivated to work on the game and to get it to a place where I can playtest with others.

So today the plan is to build the relay server, so I can actually connect two devices.

Should be relatively simple, just need to have the host client tell the server it's setting up a new game, and the server should reply with a websocket URL and mark the host's token as the owner of the room.

Then the URL can be shared with other clients which connect to the room directly as non-hosts.

Probably makes sense to use JSON for the negotiation between the WASM hosts. Also not sure if I should use rust or deno here... maybe Rust makes more sense as I've deployed Rust apps to my server already and so can probably do that fairly easily again.

So I've got the basic server up and running, and calling a POST endpoint gets it to give us a room ID. Maybe actually it should respond with the websocket URL instead.

Ok most of the Rust part is done, now it's just hooking up the web part - should be fairly straightforward.

Turns out this is one of the harder parts.... so many layers of indirection. I definitely want to clean this up once it's working.

Think it's time to call it there though. Tomorrow:

 - Stop the client from trying to connect at boot time, instead add a button to do the connection DONE
 - Once it works, split out the host and client into separate NetPeer types (for both dummy and websockets).

# Sunday 24 Aug 2025

Plan for today is to tidy up the net code. Done, and also got the relay server deployed to nix!

It works on itch.io. I just have a few things to fix before others can play it:
 - Remove websocket hot reload unless running on localhost - DONE
 - Set up itch.io butler for quick deploys DONE
 - Button to play ~~single player~~/start hosting/connect to host
 - Delete rooms when no activity after some time

Taking the rest of the day off. Tomorrow: add a basic server host/join UI, set up relay to delete old rooms.

Ended up working on the main menu, but really actually bed time now. I've got a host button working, next need to get display name entry working, then showing the URL in host mode and allowing URL entry after clicking the join button.

# Monday 25 Aug 2025

First up, displaying URL when hosting. Done, also got joining with text input working.

Next up is allowing user to change their display name, and then serializing that over the network.

Ok done! Pretty much is all working as expected after fixing a bunch of things. I think the last few things to polish before getting other players on board are:
 - Keepalive ping - stop socket from closing
 - Handle timeouts and disconnects (at least remove player from game or show a message)
 - Disable the djikstra map overlay button
 - Show feedback when clicking to pick up item (movement track and rect or something)
 - Handle dead state - spectate other players (press tab to cycle?)
 - Add some kind of goal state
 - Throwing potions

# Tuesday 26 Aug 2025

- Keepalive ping is done, and relay server also cleans up old rooms/clients

Next up I think is handling the dead state - spectate a random player for now. Or perhaps add a player list to the side to switch between players, should be easyish.
