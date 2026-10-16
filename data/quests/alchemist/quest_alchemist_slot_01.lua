-- REN'S CONSIGNMENT. A stretch of the Crucible's road lies in the rift with a crate still standing on it,
-- and a crew around the crate who opened it and have been arguing for two days about what they are
-- holding. The reagent is a PERSON -- a discard, a homunculus that came out hollow and was written down
-- as stock -- and nobody here says so. The player is simply handed a loss condition that only makes sense
-- if the cargo is alive: `assassinate` the crew's lead with `protect` layered under it.
--
-- The thing in the crate is `character_homunculus_discard`, NOT the summon: the discard is rooted and
-- built to take blows, so a protect on it is a job rather than a coin flip.
--
-- RESTORED 2026-10-14 (data/quests went in 92ff549d, and with it every way a companion could join).
-- SHE IS MET IN ENVY, the Crucible's own circle (Descent.SINS' `vendor`, Descent.dealCompanion), and
-- THE CREW IS FACELESS. It was bandits, and the rift fields no bandit any more. Envy's people wear other
-- people's faces, so "that crew" still looks like a crew -- and the circle that covets what others have is
-- the one place a body somebody else made and threw away would be stolen rather than left. The mark is
-- the COLOSSUS, the heap of the shapeless sitting on the crate: it has to stand up to being the whole job,
-- and Envy's other tier-3 Faceless are built to fall fast -- the assassin went in two hits and the
-- champion in three at this depth, under the band tests/balance_spec.lua holds a tier-3 body to -- so
-- neither stands here at all. Line Faceless stand round it, one more on the circle's second floor.
--
-- NO GOODS: the Reagent Vest is an alchemist-ladder find now (rung 9). The purse stays.
return {
    name = "The Runaway Reagent",
    description = "A stretch of the Crucible's road lies in the rift with a consignment still " ..
        "standing on it, and a crew around the crate.",
    difficulty = "Easy",
    sponsor = "alchemist",
    outro = "conversation_alchemist_slot_01_outro",
    rewardGold = 80,
    rewardCharacter = "character_ren",
    -- READ ONLY BY models/balance.lua, which still measures a quest's bodies at a campaign standing:
    -- the standing at the first floor of the circle she is met in (Envy, floor seven on the authored order),
    -- so a deep circle's stock is judged against the company that actually meets it.
    requiredPrestige = 6,
    map = {
        -- The ground of that circle. The descent picks its own ground off the floor, so this is the
        -- authored claim tests/biome_spec.lua validates, not what draws the board.
        biome = "desert",
        objective = {
            name = "The Consignment",
            composition = function(ctx)
                local list = { "character_faceless_colossus", "character_faceless", "character_faceless" }
                if require("models.descent").floorWithinCircle(ctx.depth or 1) >= 2 then
                    list[#list + 1] = "character_faceless"
                end
                return list
            end,
            allies = { "character_homunculus_discard" },
            win = {
                type = "assassinate",
                target = "character_faceless_colossus",
                enemy = "the crew that took the crate",
                protect = "character_homunculus_discard",
            },
        },
    },
}
