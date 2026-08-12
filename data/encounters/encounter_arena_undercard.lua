-- The debut's warm-up bout (data/quests/arena_debut.lua): a house sparring pair on the walk to the
-- tunnel mouth, and the one job it does is TEACH THE NET before the net can lose a fight. The main
-- event fields Saber over two Trappers, and a new player meets Root for the first time there -- pinned,
-- and punished for being pinned, in the same breath. This stop moves that first lesson somewhere it can
-- be learned safely.
--
-- It is a miniature of the real card minus the boss: one Trapper (data/characters/character_trapper.lua,
-- the SAME soft netter fielded in the bout, so this is literally "these are the people who will hold
-- you") plus one bandit for melee pressure, so the player cannot simply ignore the netter and walk. The
-- read it drills is the read the bout demands: the pin comes from the Trapper, so kill the Trapper and
-- the pins stop. A found cleanse kit (data/conversations/arena_debut_kit.lua) is the other half of the
-- answer, picked up on the same approach.
--
-- `weight = 0`: authored-only, reached through arena_debut's `map.encounters.always` (like the siege and
-- survivor encounters), never rolled into an ordinary board's pool. Default `killAll` win on a rolled
-- castle field -- no objective or authored arena needed; the lesson is the enemy composition, not the
-- ground.
return {
    name = "Undercard: House Sparring",
    kind = "combat",
    weight = 0,
    minDay = 1,

    -- One netter, one bruiser. The Trapper pins; the bandit makes standing still cost something, so the
    -- player has to solve the pin rather than wait it out. Deliberately small -- this is the sparring
    -- bout that teaches the mechanic, not a second climax before the real one.
    composition = function()
        return { "character_trapper", "character_bandit" }
    end,
}
