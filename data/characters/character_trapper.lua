-- A Trapper: one of the two bodies the house puts on the sand beside Saber in the debut bout
-- (data/quests/arena_debut.lua), and the pair her fight is built around. Every team in the Colosseum is
-- a team (docs/story.md, "The Colosseum"), so the veteran the house booked does not fight alone -- it
-- hires trappers, and their whole job is to make her one big swing land.
--
-- It is a TRAPPER, not a wall. The old debut fielded a plain bandit here -- a body to soak a hit -- and
-- the trouble was that a wall does nothing about the real problem, which is that the player can simply
-- step out of Saber's telegraphed blow. This one carries the Bolas (data/items/ability/ability_bolas.lua):
-- range-3 Root, so it PINS the body Saber is about to commit to. The read is legible on purpose -- you
-- can see who is holding you, and killing the trapper frees the ground -- so "I got rooted and eaten" is
-- a targeting decision (drop the trappers first) rather than a tax the arena charges you.
--
-- Deliberately soft. It is a spotter for the greatsword, not a second greatsword: low health, an iron
-- bow to plink from range once a foe is already pinned, and no boss protection. A party that reads the
-- fight kills them early and the pins stop; a party that ignores them feeds Saber a rooted target every
-- other turn.
--
-- `archetype = "skirmish"` because it fights at range: a trapper wants to keep its distance and hold a
-- line, not close and brawl -- and a bow cannot even fire at an adjacent tile (weapon_iron_bow's
-- minRange 2), so an aggressive footwork that walked into melee would strand its fallback weapon.
return {
    name = "Trapper",
    sprite = "assets/chars/bandit.png", -- reuses bandit art until its own exists
    archetype = "skirmish",             -- keeps its range; see the note above
    stats = {
        health = 34, mana = 0, stamina = 16, -- softer than a bandit: it is support, and meant to fall first
        staminaRegen = 2,                     -- enough to keep the net coming; see ability_bolas' cost
        damage = 10, magicDamage = 0,
        defense = 6, magicDefense = 3,
        movement = 4,
        speed = 3, -- a shade quicker than a bandit in the order: it wants to net BEFORE Saber commits
    },
    -- The net is the tool; the bow is the fallback. Bolas in a free cell (it needs no weapon beside it
    -- -- the snare IS the tool), an iron bow for shooting a pinned foe, nothing bound.
    startingItems = {
        false, "ability_bolas",   false,
        false, "weapon_iron_bow", false,
        false, false,             false,
    },
    defaultAction = "ability_bolas",
    ai = {
        -- 1. Net an UNPINNED foe at range: the setup half. Skips anyone already rooted -- one net holds
        -- as well as two, and a wasted throw is a turn Saber's target got to walk. `lacks_status` fires
        -- while any foe is still loose; first-match-wins means a foe already rooted falls through to the
        -- bow rule instead of being netted twice.
        { priority = "high", act = "cast", item = "ability_bolas",
          when = { subject = "any_foe", test = "lacks_status", value = "status_root" } },
        -- 2. Everyone in reach is already pinned: put an arrow into one. Reached only when rule 1 found
        -- nobody left to net, so this is the "if already rooted, use the bow" half -- it plinks the
        -- pinned foe from range rather than closing to brawl, which a spotter has no business doing.
        { priority = "normal", act = "attack", item = "weapon_iron_bow",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
