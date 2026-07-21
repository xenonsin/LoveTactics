-- The village fight's lesson: the prologue's first battle, taught step by step (models/tutorial.lua).
-- See states/prologue.lua for where it is fielded.
--
-- Each step speaks TWICE, and the split is the point:
--
--   `line`  -- what Rowan says, in her panel under the board. Pure fiction. She is a knight in a
--             burning village; she does not know what a mouse is, and the moment she says "click the
--             purple tile" she stops being a character and becomes a manual.
--   `coach` -- the interface instruction, in a small bubble pinned to the exact thing it is talking
--             about (`anchor`): the tile, the ability in the item grid, the imp, a card in the turn
--             order. This is where "click", "tile" and "ability" are allowed to live.
--
-- So the fiction stays clean and the instruction stays unambiguous, and neither has to carry the
-- other's job. Both are localized through data/conversations/tutorial_village.lua.
--
-- Pure data, deliberately: no closures anywhere in this file. Every target is an id and a fixed cell
-- on a fixed board (data/arenas/tutorial_village.lua), which is what buys that -- a predicate like
-- "the nearest imp" would need a function and could not be checked by a test.
--
-- ============================================================================================
-- THE SHAPE OF THE LESSON
--
-- Read the `steps` below as only HALF the fight. A step is a thing the PLAYER does; everything
-- between them -- Rowan's kills, the imps' advance, the grunt walking on -- is the `script` at the
-- bottom. The two interleave into one continuous scene, which is why the fight teaches by being
-- watched as much as by being played:
--
--   A scene plays over the board, and nothing moves until you dismiss it   (`opening`)
--   Rowan crosses two tiles and cuts down her imp (script: her authored demonstration)
--   1. DO THE SAME to yours, in one click         <- a kill, first thing, before anything else
--   ...three more imps come, and two of them spit at you both   (script: their authored advance)
--   Rowan cuts down the one that reached her      (script: her standing guard)
--   2. ADVANCE to the tile between the other two  <- movement alone, now that a tile is worth something
--   3. READY the Clear Out she just handed you        <- (a grunt walks on behind them here)
--   4. CLEAR OUT, and both fall at once               <- the payoff: position, then one blow for two
--   ...the grunt reaches you and swings, and your own sword answers it unbidden (Parry)
--   5. READY the Jolt                             <- a MANA cost, and exactly enough for one cast
--   6. JOLT the grunt, which reels                <- the stun, and with it the turn order
--   Rowan steps off her post and lands one blow   (script: her only move all fight)
--   7. STRIKE it down before it comes around      <- why the stun mattered: you bought this turn
--
-- ...and that last blow KILLS it and wins the battle. The lesson does not narrate the player up to
-- the victory and then take the controls back for it -- the grunt is left standing inside exactly
-- one sword-stroke (the sum under `spawn`), and the player's own click is what ends the fight. The
-- first fight anyone plays should be one they finished, not one they watched finish.
--
-- Why this order, on the two points that were genuinely a choice:
--
--   * The player's first action is a KILL, not a move -- but the kill contains the move. An earlier
--     draft opened with a bare "step one tile east", and it taught the interface rather than the
--     game: the first thing anyone ever did was shuffle. Here the imp stands three tiles off and one
--     click both walks the avatar to it and swings (tryDefaultAction), so the opening beat is a
--     crossing AND a body falling, which is the actual shape of every attack in this game. The
--     weapon is already drawn (the battle arms a unit's default action at the start of its turn) and
--     step 1 deliberately does NOT teach arming: a first lesson about clicking your own sword before
--     you may use it is a lesson about menus. Bare movement waits for step 2, where a specific tile
--     is finally worth standing on.
--   * ROWAN kills first, one beat ahead of the player, every time -- and her kill is a walk and a
--     blow, the same two things the player is about to be asked for. She is the mentor; showing it
--     and then asking for it is worth more than either alone, and it is the honest way to introduce
--     a companion who will be fighting beside them for the rest of the game.
--   * NOBODY IS IN REACH AT THE START. Both of those demonstrations need ground to cross, or the
--     lesson silently becomes "click the thing next to you" and the board stops being a board.
-- ============================================================================================
return {
    arena    = "tutorial_village",
    lines    = "tutorial_village",
    -- Played once, over the board, before a single turn resolves (states/battle.lua fields it on
    -- enter; a conversation is an overlay on a FROZEN state, so the lane is visible behind it). It
    -- exists to give Rowan's opening kill somewhere to land: without it her demonstration resolves in
    -- the first half-second of the fight, while the player is still working out what a tile is.
    opening  = "prologue_village",
    speaker  = "character_knight",     -- whose panel and portrait carry the narrative half
    scripted = { "character_knight" }, -- Rowan runs her authored turns, not the player's hands
    -- THE TURN ORDER IS AUTHORED, like everything else here. See Tutorial.startInitiative /
    -- Tutorial.paceTurn for the mechanism; this is why it exists.
    --
    -- Left to initiative the sequence above does not come out, and cannot be made to. Rowan swings a
    -- mace and the avatar a sword, so his turns come round faster than hers -- which means the
    -- student cycles twice for each of her demonstrations, and every beat where she is supposed to
    -- act FIRST lands second instead. It cost the lesson two of them: her opening kill (the whole
    -- reason the scene above is played) and her standing guard, which is the only thing that ever
    -- clears the third imp off her flank. Nudging one beat straight just bent another, because
    -- initiative is a running total: change a number anywhere and everything after it shifts.
    --
    -- The fight, turn by turn, by script key. Position sets each unit's starting tick and the gap to
    -- its next appearance sets what its turn costs it (Tutorial.startInitiative / Tutorial.paceTurn).
    -- The two vanguards are deliberately absent: they die on the opening pass, and a unit the list
    -- never names is seated behind the whole lesson.
    --
    -- IT IS A PLAN, NOT A CAGE, and one entry proves it. The grunt is listed TWICE, and the second
    -- turn is one it must never actually take: it is there so that when the player casts the Jolt the
    -- grunt is genuinely the next card up -- a real turn, about to happen, with a wounded party in
    -- front of it -- and so that the stun has something to shove. The stun adds to the initiative
    -- this list handed it, the card slides below both party members, and the two turns that buys are
    -- exactly the two it takes to kill it. Freeze the order outright and that beat teaches nothing;
    -- leave the order to initiative and it never lines up at all.
    pace = {
        order = {
            "character_knight",  -- her demonstration: cross the lane, cut the vanguard down
            "character_avatar",  -- 1. the same, in one click
            "4,2", "6,2",        -- the second wave closes and spits
            "7,3",               -- ...and the third takes the long way to her flank
            "character_knight",  -- her post answers it
            "character_avatar",  -- 2-4. advance, ready, Clear Out -- and the grunt walks on
            "6,1",               -- it charges, and the avatar's sword parries unbidden
            "character_knight",  -- her mace answers, and shoves it two tiles clear
            "character_avatar",  -- 5-6. ready the Jolt and throw it
            "6,1",               -- the turn the STUN takes away from it (see above)
            "character_knight",  -- the blow that stun bought her
            "character_avatar",  -- 7. and the killing stroke is the player's
        },
    },

    -- One player action per step; the step completes when that action resolves. Ordered.
    steps = {
        -- Cross the lane and cut the vanguard down, with the weapon already in hand. ONE click does
        -- both: clicking a foe inside move-plus-reach walks the avatar into range and swings from
        -- where the walk ends (tryDefaultAction in states/battle.lua). So the first thing the player
        -- ever does is still a kill -- it simply has a step in front of it, which is the honest shape
        -- of every attack in this game and worth learning on the one that cannot go wrong.
        --
        -- Pinned to the vanguard's cell as well as its blueprint id: two imps are in play on turn one
        -- and this names the avatar's, so the reach highlight shows exactly one square and Rowan's
        -- kill stays hers.
        --
        -- `approach` is what makes this survivable as a FIRST step, and it is also the step's second
        -- lesson. The player holds a full move, and an attack step normally leaves the blue band
        -- alone -- so they could spend it wandering, then owe a strike on a body they can no longer
        -- reach with every other action refused. Naming the one tile the blow can be thrown from
        -- closes that off AND makes the blue band mean "stand here to hit it", which is the thing
        -- being taught. (4,6) is the near side of the imp, two tiles out; the far tiles are legal
        -- ground but a longer walk, and a first lesson should have one answer.
        -- `calm` strips the danger paint for this step only: the purple wash over move tiles a foe
        -- could reach, and the red lines traced back from the bodies that threaten the tile under the
        -- cursor. Both are among the most useful things this game draws, and both are the wrong FIRST
        -- thing to see -- a board speaking in three colours about a threat model nobody has explained
        -- yet reads as noise, and the one instruction on screen is "click the imp". So the opening
        -- shows two things, the tile to stand on and the body to hit, and the colours start meaning
        -- something from step 2 onward.
        { line = "strike", coach = "strike_hint", actor = "character_avatar", nudge = "nudge",
          calm = true,
          gate = { kind = "attack", target = "character_demon_imp", item = "weapon_iron_sword",
                   cells = { { x = 4, y = 5 } }, approach = { { x = 4, y = 6 } } },
          anchor = { kind = "unit", char = "character_demon_imp" } },

        -- Advance to the one tile that touches both surviving imps at once, and collect the ability
        -- that makes that worth doing: `grant` puts Clear Out in the avatar's grid the moment this step
        -- becomes current, which is while Rowan is still saying she is handing it over. It stays
        -- there after the battle -- the art is the avatar's now, not a prop.
        --
        -- Exactly one tile is legal, and it is (5,4): the imps are driven to (4,4) and (6,4), so this
        -- is the only square adjacent to both. Everything else on the blue band is filtered out, so
        -- "a lit tile" is literally the only lit tile.
        { line = "advance", coach = "advance_hint", actor = "character_avatar", nudge = "nudge",
          grant = "ability_clear_out",
          gate = { kind = "move", cells = { { x = 5, y = 4 } } },
          anchor = { kind = "cell", x = 5, y = 4 } },

        -- Ready the Clear Out. The battle normally arms a unit's default action for it at the start of
        -- every turn; models/tutorial.lua's arm step suppresses that (states/battle.lua), because a
        -- lesson about picking up an ability is worthless if the sword is already drawn over it.
        --
        -- The reinforcement walks on HERE rather than after the Clear Out lands, and the reason is
        -- mechanical: the Clear Out kills the last two imps, and an empty enemy side ends the battle on
        -- the spot (Combat.evaluate). The grunt has to already be standing for that blow to be the
        -- middle of the fight instead of the end of it. It also plays better -- the player watches it
        -- come while they wind up, rather than having it appear out of a cleared field.
        --
        -- THE GRUNT'S 40 HEALTH IS SPENT EXACTLY, and every number below is load-bearing. The last
        -- beat of this lesson is the player landing a killing blow themselves, which only reads as
        -- one if the grunt is genuinely one stroke from death when they swing -- not two, and not
        -- already dead. tests/tutorial_spec.lua pins the whole sum:
        --
        --   66  the grunt walks on and charges the avatar
        --   -14 its swing is PARRIED by the avatar's iron sword (data/traits/trait_parry.lua)
        --   -18 Rowan's mace -- which also SHOVES it two tiles clear (see below)
        --   = 34 ...and now it is standing three tiles off, with a turn of its own coming
        --   - 6 the Jolt, thrown across that gap -- and with it a Stun, +5 on its initiative
        --   -22 Rowan's second blow, on a turn the stun just bought her: 18 from the mace, and 4
        --       more because this shove has nowhere to go and slams it into the top of the board
        --       (Combat.knockback bills a collision at the weapon's own power)
        --   = 6 ...and a 14-damage sword stroke ends it. The player's click wins the battle.
        --
        -- Which is why the grunt and Rowan are both scripted through this stretch rather than left
        -- to the AI: a wandering ally or an extra swing anywhere in that column and the grunt either
        -- dies to somebody else or survives the ending. Note 28 > 18 deliberately -- Rowan CANNOT
        -- finish it on her own turn, however well she rolls, because the last blow is not hers.
        --
        -- THE ORDER IS THE LESSON, twice over, and it only comes out one way:
        --
        --   * The grunt claims initiative 0 so it charges the instant it lands. Rowan answers on the
        --     next turn, and the player's turn finds a foe suddenly three tiles away. That gap is the
        --     point -- Jolt reaches three tiles, and a Jolt thrown at something already at arm's
        --     length teaches nothing about range. Her mace opens it, which is also the first time the
        --     player sees that moving a body is a thing a weapon can do.
        --   * Then the timeline itself. The grunt is the NEXT card when the player casts -- a real
        --     turn, about to happen, with a wounded party in front of it. The Jolt's stun shoves it
        --     below both of them, and the two turns that buys are exactly the two it takes to kill it.
        --     The player is not told the stun was worth it; they watch a card slide and then get to
        --     spend what sliding it bought. That is the whole lesson, and it is why the grunt has 60
        --     health rather than enough to die a beat sooner.
        { line = "ready", coach = "ready_hint", actor = "character_avatar", nudge = "nudge",
          gate = { kind = "arm", item = "ability_clear_out" },
          anchor = { kind = "item", id = "ability_clear_out" } },

        -- Throw it. A Clear Out is centred on the body that spins, so the cell being aimed at is the
        -- avatar's own -- the tile it was just walked onto -- and the ring it sweeps takes both imps
        -- together.
        { line = "clear", coach = "clear_hint", actor = "character_avatar", nudge = "nudge",
          gate = { kind = "attack", item = "ability_clear_out", cells = { { x = 5, y = 4 } } },
          anchor = { kind = "cell", x = 5, y = 4 } },

        -- Ready the Jolt, and with it the OTHER pool. Everything the player has spent so far came
        -- out of stamina, which refills between battles and regenerates while they stand there; mana
        -- does neither. The avatar has exactly 10 and a Jolt costs exactly 10, so the lesson does not
        -- have to say "it is scarce" -- the bar empties in one cast and says it better.
        --
        -- Pinned to the SLOT rather than to the avatar's resource bars, though the bars were the
        -- first instinct: the slot carries the cost badge, and that badge is a purple diamond where
        -- every other item's is a stamina drop. Pointing at the number that is a different colour
        -- teaches the distinction in one glance; pointing at a bar only says "look, a bar".
        -- THE FEET ARE PINNED from here to the end -- `approach = {}`, an approach with no tiles in
        -- it. These last three steps open a FRESH turn (the Clear Out ended the last one), so the player
        -- holds a full move again, and every one of them needs the avatar standing exactly where the
        -- Clear Out left it: the grunt is walked to the one cell that is in Jolt's reach, in sword reach,
        -- and in Rowan's, and the closing arithmetic is counted from there. A player who wandered
        -- off would be out of range of the only action the gate still allows, with no way to end the
        -- turn -- the same trap `approach` was invented for on step 1, arriving three more times.
        --
        -- Nothing is lost by it: the grunt is already adjacent, so there was never a step worth
        -- taking. The blue band simply shows no tiles, and the one thing to do is the thing lit up.
        -- The grunt walks on HERE, on the first step after the Clear Out -- so the player sees the two
        -- imps fall and the answer arrive, in that order, rather than watching reinforcements loom
        -- behind a fight they have not finished. It is claimed in resolveAdvance, ahead of the
        -- objective check, because the blow that clears the last imp would otherwise WIN the battle
        -- (an empty enemy side is a victory) a beat before the body that the rest of the lesson is
        -- about. Tutorial.awaitsSpawn is what holds that win open for exactly one beat.
        { line = "spark", coach = "spark_hint", actor = "character_avatar", nudge = "nudge",
          grant = "ability_jolt",
          -- -1, not 0, and the sign is load-bearing: the grunt must act BEFORE the mentor, whose own
          -- next turn is the shove that answers this charge. At 0 it merely tied with her, and a tie
          -- between two party-and-enemy units goes to the party -- so she threw the shove at an empty
          -- cell a beat early, the grunt was never driven back, and every step after it was aimed at
          -- a body standing somewhere else. A seat ahead of the whole board says "acts next" outright;
          -- the next rebase normalizes it away.
          spawn = { { char = "character_demon_grunt", x = 6, y = 1, initiative = -1 } },
          gate = { kind = "arm", item = "ability_jolt", approach = {} },
          anchor = { kind = "item", id = "ability_jolt" } },

        -- Jolt the grunt. Named by blueprint id with NO cells -- it walked in on its own script and
        -- the lesson pins the body, not the tile.
        { line = "jolt", coach = "jolt_hint", actor = "character_avatar", nudge = "nudge",
          gate = { kind = "attack", item = "ability_jolt", target = "character_demon_grunt",
                   approach = {} },
          anchor = { kind = "unit", char = "character_demon_grunt" } },

        -- ...and collect what the Jolt bought. A Stun adds ticks to the target's initiative
        -- (data/status/status_stun.lua), so the grunt's card visibly slides DOWN the turn order and
        -- the avatar comes back around before it does. This step's coaching is pinned to that card:
        -- the one moment in the whole game where the timeline is not abstract, because the player
        -- just moved it themselves and can watch the consequence in the same breath.
        --
        -- The last thing the lesson ever asks for, and the blow that WINS the battle: Rowan's strike
        -- has left the grunt inside one sword-stroke, so this click is both the final instruction and
        -- the player's own victory. Deliberately not a step the tutorial narrates them through and
        -- then takes over from -- the first fight ends on the player's hand, or it was never theirs.
        -- ...and this one DOES walk. Rowan's shove put the grunt two tiles out, which is what made
        -- the Jolt a ranged throw -- and it means the closing sword stroke has ground to cover again.
        --
        -- (6,2) is that tile, and reading why takes both of Rowan's blows. Her first shove drives the
        -- grunt from (6,4) to (6,2). Her second lands on it there and shoves AGAIN -- but the board
        -- ends at row 1, so it travels one cell into the top edge and stops at (6,1), taking the
        -- collision damage the closing arithmetic counts. That is what frees (6,2): the cell the grunt
        -- was standing on a moment ago, directly beneath it, with Rowan behind at (6,3) and the near
        -- side left open. One step from where the Clear Out left the avatar, then the blow, in one click.
        { line = "finish", coach = "finish_hint", actor = "character_avatar", nudge = "nudge",
          gate = { kind = "attack", target = "character_demon_grunt", item = "weapon_iron_sword",
                   approach = { { x = 6, y = 2 } } },
          anchor = { kind = "turn", char = "character_demon_grunt" } },
    },

    -- Hand-driven turns, popped one per turn of the unit they belong to. Keyed by SCRIPT KEY rather
    -- than interleaved into `steps` because turn order is initiative-driven: which of these falls
    -- between which of the player's is not knowable from here, and a queue stays correct either way.
    --
    -- A party member is keyed by character id; an enemy by the CELL IT SPAWNED ON, because all five
    -- imps share one blueprint id and only their marks tell them apart (states/battle.lua stamps
    -- `scriptKey`). The two vanguards are named nowhere below -- they die on the opening exchange
    -- and never get a turn.
    --
    -- Every queue here goes quiet the moment the lesson finishes (Tutorial.scriptFor checks `done`),
    -- which is what hands Rowan back to the ordinary AI for the grunt fight at the end.
    script = {
        -- Rowan's standing order, and the only entry kind she is ever given: hold this post, cut
        -- down whatever reaches it, never take a step.
        --
        -- `guard` rather than authored cells because WHICH imp walks into her reach, and on which of
        -- her turns, depends on the initiative order -- and this file cannot know it. And `guard`
        -- rather than the ordinary AI because she must never take a step: every tile she might
        -- advance to is one the choreography needs empty, and any foe she might close on is one the
        -- player's own lesson is saving for them. Standing still is what makes her safe to script.
        --
        -- Eight is simply more turns than she can get before the lesson ends; the queue is not meant
        -- to be counted, and running it dry would only hand her to the AI a little early.
        -- ...until the very end, where she steps off her post exactly once. By then the imps are
        -- gone, so there is no choreography left to protect and no kill left to steal -- and the last
        -- beat of the fight is supposed to be the two of them working on the same body. Her blow is
        -- what leaves the grunt inside a single sword-stroke of death, so the player's next click
        -- ends the battle. See the arithmetic note under `spawn` above.
        character_knight = {
            -- The demonstration: she crosses to the vanguard on her side and cuts it down. Authored
            -- as a move-and-strike rather than a guard precisely because the WALK is half of what she
            -- is showing -- the player is about to be asked for the same two things in one click.
            { move = { x = 6, y = 6 }, strike = { x = 6, y = 5 } },
            -- ...then she holds the ground she took, for as many turns as the imps are the fight.
            -- `through = 4` is what makes that a post rather than a turn: the entry is offered again
            -- every turn of hers until the lesson passes step 4 (the Clear Out), so it cannot be spent
            -- early on an empty board and cannot outlive the phase it belongs to. See
            -- Tutorial.scriptFor.
            --
            -- Counting turns here instead was the original bug and could not have been made to work.
            -- WHICH of her turns the third imp arrives on depends on the initiative order, and this
            -- file is not allowed to know it -- so a single guard could come up one turn early, find
            -- nothing, and be spent, leaving the imp alive at her elbow for the rest of the fight
            -- while she walked off to the shove. Doubling it only moved the problem: the spare would
            -- then eat the shove's own turn on a board with nothing left to guard, which is precisely
            -- how the doubled shove below went wrong. The post lasts as long as the phase does.
            { guard = true, through = 4 },
            -- The shove, twice over -- and the repeat is the safety net, not a second blow. Whichever
            -- of these two turns finds the grunt standing on (6,4) swings the mace at it; the other
            -- finds an empty cell and holds (scriptedAction only strikes a living foe). It cannot
            -- double-hit, because the first swing knocks the thing two tiles clear of the very cell
            -- the second one aims at. Two entries because exactly when the grunt arrives depends on
            -- the initiative order, and this file is not allowed to know it.
            { move = { x = 6, y = 5 }, strike = { x = 6, y = 4 } },
            -- ...and then she follows it, twice authored for the same reason the shove was: whichever
            -- of these turns finds the grunt on the cell the shove put it, takes it. This is the blow
            -- the JOLT buys -- stunned, the grunt drops below both of them in the order, so she gets a
            -- turn it does not, walks to where it landed and hits it again. She leaves it inside one
            -- stroke and never finishes it, which is the player's to do; and she takes (6,3) rather
            -- than (5,2) so the near tile stays free for them to close on (see the finish step).
            --
            -- The SHOVE is authored only once now, deliberately. It used to be doubled as a safety
            -- net, and the spare copy quietly ate this turn instead -- aiming at a cell its own first
            -- swing had knocked the grunt out of, so she stood there holding while the player took
            -- the kill she was supposed to set up.
            { move = { x = 6, y = 3 }, strike = { x = 6, y = 2 } },
            { move = { x = 6, y = 3 }, strike = { x = 6, y = 2 } },
        },
        -- The second wave, driven rather than left to the AI for one reason: steps 2 and 4 name exact
        -- tiles, and those tiles only mean anything if the imps are standing where the lesson says.
        --
        -- Each closes to two tiles of its mark and spits from there, because an imp adjacent to a
        -- swordsman is a dead imp (Parry answers any adjacent blow, and an iron sword's answer is
        -- more than an imp has health). The first two leave (5,4) empty between them for the player.
        -- Their marks are read off where the OPENING KILLS leave the party standing -- the avatar at
        -- (4,6) and Rowan at (6,6), each having crossed two tiles to swing -- not off the spawns.
        ["4,2"] = { { move = { x = 4, y = 4 }, strike = { x = 4, y = 6 } } }, -- spits at the avatar
        ["6,2"] = { { move = { x = 6, y = 4 }, strike = { x = 6, y = 6 } } }, -- spits at Rowan
        -- The third takes the long way round to Rowan's flank and gets close enough to be cut down
        -- for it -- it has no strike, because from (7,6) it is standing too close to spit (Cinder
        -- Spit has no point-blank shot). It exists to be her second kill: a body the player watches
        -- her deal with while their own two are lining up.
        ["7,3"] = { { move = { x = 7, y = 6 } } },
        -- The grunt, from the cell it is walked on at. It closes on the avatar and swings -- and
        -- being swung at is the point of the beat as much as the damage is: an iron sword answers an
        -- adjacent blow (Parry), so the player's own weapon hits back without being asked, which is
        -- the first time anyone sees that happen.
        --
        -- IT IS ALSO THE FIRST BLOW THAT ACTUALLY HURTS, and that is load-bearing for the two steps
        -- after it. Its Rending Claws take 20 off a 62-health avatar in one swing
        -- (data/items/weapon/weapon_rending_claws.lua) -- a third of the bar, from a body that walked
        -- on ten seconds ago and is the next card in the timeline. Steps 5 and 6 then ask the player
        -- to empty their ENTIRE mana pool on a Jolt whose only effect is to push that card down the
        -- order, and nobody spends everything they have to delay a thing that tickles. The grunt used
        -- to swing a borrowed iron sword for 6, and the Jolt was a move the lesson had to insist on
        -- rather than one the board asked for. The damage is the argument; the coaching only names it.
        --
        -- Scripted rather than left to its AI because everything after it is counted (see `spawn`):
        -- the parry, the Jolt and Rowan's blow have to land on a known body at a known cell.
        --
        -- (6,4) is that cell, and it is picked from Rowan's side of the problem rather than the
        -- grunt's. She is in CHAINMAIL, which costs her a point of movement, so she covers two tiles
        -- and not three -- and (6,4) is the only square that is at once adjacent to the avatar (so
        -- the grunt has someone to swing at), within one step-and-a-swing of Rowan, and NOT adjacent
        -- to her, so her standing guard doesn't cut the grunt down early and spoil the sum.
        --
        -- It walks on at (6,1) rather than further off for the same arithmetic: one move gets it
        -- here, so it arrives on its first turn and every beat after it is countable.
        --
        -- The two HOLDS after the charge are what make the shove mean anything. A scripted unit falls
        -- back to the ordinary AI the moment its queue runs dry, and the AI's answer to being knocked
        -- two tiles back is to walk straight in again -- which it did, closing the gap before the
        -- player ever got a turn to look at it, and turning the ranged Jolt back into a point-blank
        -- one. So it reels: shoved, it stays shoved, for the beat the lesson needs. It is stunned by
        -- the end of it anyway, and the fight is over before it would have moved again.
        ["6,1"] = {
            { move = { x = 6, y = 4 }, strike = { x = 5, y = 4 } }, -- charge the avatar; the sword answers
            { hold = true }, { hold = true },
        },
    },
}
