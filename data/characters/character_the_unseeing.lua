-- THE UNSEEING: a blind boar lord who never touches you, and the clan that does.
--
-- HE CARRIES NO WEAPON. That is the design, not an omission -- there is no entry in `startingItems` that
-- can hurt anybody, and the only thing he does with a turn is ability_the_call. Every other boss in this
-- folder is a body you fight; this one is a body you have to REACH, through the thing it keeps making.
-- The fight's whole first half is the sounder (data/items/ability/ability_gore.lua) at a scale the road
-- never fields it, and he is the reason there keep being more lanes.
--
-- Which is what makes the turning land. A body that has not laid a finger on you for half a fight
-- suddenly moving is a different event from a boss getting angrier, and character_the_turning is where
-- all of his damage has been the whole time.
--
-- SLOW AND WIDE ON PURPOSE. Movement 2 on a 2x2 body: he does not chase and does not need to, because
-- the clan does the closing. His bulk is denial -- a four-tile animal in a forest carve is a cork -- and
-- cornering him is worth doing for a second reason, since fx.openTileNear finds nothing to set a boar
-- down on when he is hemmed in and the call quietly comes up short.
--
-- Tier 3's band is 81-154 health, which is where a beast apex on a road sits here (compare
-- character_the_winter_hart at 136 and character_rift_born at 132). The stamina line is what lets the
-- call run every turn rather than every other one -- 6 a cast against 3 a tick is the pace of the fight.
--
-- The blindness is currently FICTION rather than mechanism. What was designed for it -- the clan aiming
-- at whoever last wounded him -- wants a new AI targetPref and is not built; see docs/bestiary.md if it
-- ever is. What ships is the immunity below, which is the one half of it that costs nothing: there is
-- nothing in those eyes to take.
return {
    name = "The Unseeing",
    kind = "beast",
    tier = 3,
    boss = true, -- the fight is it: off the execute and Charm tables (tests/charm_balance_spec.lua)
    sprite = "assets/chars/the_unseeing.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 138, mana = 0, stamina = 20,
        staminaRegen = 3, -- the call costs 6; this is what makes it a turn rather than a cooldown
        damage = 12, magicDamage = 0,
        defense = 11, magicDefense = 8,
        movement = 2, -- he does not chase. The clan closes.
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 3, -- a blind animal is not a precise one, and it does not dodge what it cannot see
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Decades of bristle and scar over a frame nothing on this road has ever got through.
    --   Nothing got through it. Something got IN it, once, and that is the whole story of this animal.
    resist = { slash = 4, impact = -4 },
    startingItems = { "ability_the_call", "utility_the_iron_in_him" },
    -- WHAT HE IS KNOWN FOR. None of it is his own kit -- the Call, the Iron and the Hide are
    -- `class = "creature"` and carry no axis at all, so the pool cannot mint them and a boss's whole
    -- fight can never be handed to the player (docs/bestiary.md). These are the two things he DOES,
    -- rebuilt as gear somebody could carry.
    --
    -- ORDERED BY DEPTH, WHICH IS THIS SYSTEM'S RARITY. A floor picks a rank before it looks at who died
    -- (Spoils.rankBand), so an item only drops on floors that reach its own `dropTier` -- and since the
    -- tier is DERIVED from what a thing is worth (tools/drop_tier.lua), the rarer piece is rarer because
    -- it is stronger rather than because a number says so. The horn is the one you will see; the Last
    -- Sounder is the chase.
    drops = { "utility_the_wake", "utility_treeline_horn", "utility_the_last_sounder" },
    defaultAction = "ability_the_call", -- there is nothing else in the kit to fall back to
    archetype = "defensive", -- he holds ground and makes more of the clan; he does not come to you
    ai = {
        { priority = "high", act = "support",
          when = { subject = "any_ally", test = "count_at_most", value = 4 } },
    },
}
