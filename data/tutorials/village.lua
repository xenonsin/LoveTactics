-- The village fight's lesson: the prologue's first battle, taught step by step (models/tutorial.lua).
-- See states/prologue.lua for where it is fielded.
--
-- Each step speaks TWICE, and the split is the point:
--
--   `line`  -- what Rowan says, in her panel under the board. Pure fiction. She is a knight in a
--             burning village; she does not know what a mouse is, and the moment she says "click the
--             purple tile" she stops being a character and becomes a manual.
--   `coach` -- the interface instruction, in a small bubble pinned to the exact thing it is talking
--             about (`anchor`): the tile, the weapon in the item grid, the demon. This is where
--             "click", "tile" and "weapon" are allowed to live.
--
-- So the fiction stays clean and the instruction stays unambiguous, and neither has to carry the
-- other's job. Both are localized through data/conversations/tutorial_village.lua.
--
-- Pure data, deliberately: no closures anywhere in this file. Every target is a character or item id
-- and a fixed cell on a fixed board (data/arenas/tutorial_village.lua), which is what buys that -- a
-- predicate like "the nearest demon" would need a function and could not be checked by a test.
return {
    arena    = "tutorial_village",
    lines    = "tutorial_village",
    speaker  = "character_knight",     -- whose panel and portrait carry the narrative half
    scripted = { "character_knight" }, -- Rowan runs her authored turns, not the player's hands

    -- One player action per step; the step completes when that action resolves. Ordered. All three
    -- land on the avatar's FIRST turn: the board puts a demon within a two-tile advance, so move,
    -- ready, strike is one continuous lesson rather than a wait for the enemy to wander over.
    steps = {
        -- Move: exactly one tile is legal, and it is the one that puts the avatar in the vanguard
        -- demon's face. Everything else on the blue band is filtered out, so "a lit tile" is
        -- literally the only lit tile.
        { line = "move", coach = "move_hint", actor = "character_avatar", nudge = "nudge",
          gate = { kind = "move", cells = { { x = 4, y = 5 } } },
          anchor = { kind = "cell", x = 4, y = 5 } },

        -- Ready the weapon. The battle normally arms a unit's default action for it at the start of
        -- every turn; models/tutorial.lua's arm step suppresses that (states/battle.lua), because a
        -- lesson about clicking your sword is worthless if the sword is already drawn.
        { line = "arm", coach = "arm_hint", actor = "character_avatar", nudge = "nudge",
          gate = { kind = "arm", item = "weapon_iron_sword" },
          anchor = { kind = "item", id = "weapon_iron_sword" } },

        -- Strike: named by character id with NO cells. Any grunt, approached any legal way, satisfies
        -- the lesson -- by now they are moving under their own AI and their tiles are not knowable
        -- from here.
        { line = "strike", coach = "strike_hint", actor = "character_avatar", nudge = "nudge",
          gate = { kind = "attack", target = "character_demon_grunt" },
          anchor = { kind = "unit", char = "character_demon_grunt" } },
    },

    -- Rowan's authored turns, popped one per turn of hers. Keyed by character id rather than
    -- interleaved into `steps` because turn order is initiative-driven: which of her turns falls
    -- between which of the player's is not knowable from here, and a queue stays correct either way.
    --
    -- She moves up the lane first, making good on "to my side" before she asks it of anyone. The
    -- queue then runs dry and she fights under the ordinary AI -- by then the lesson is over, and a
    -- scripted strike could only aim at a tile the demons have already left.
    script = {
        character_knight = {
            { move = { x = 5, y = 5 } }, -- forward with you, one shoulder over
        },
    },
}
