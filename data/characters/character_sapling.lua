-- A SAPLING: a yew planted mid-fight by the Nymph's Seedfall (or by a company carrying the spell, or by
-- Heartwood). An object, not a combatant -- it takes no turns and it can be cut down -- and a PLANT, which
-- is the whole reason it exists (models/grove.lua): the grain the Dryad line steps through.
--
-- WHY A BODY AND NOT A WALL. A conjured wall is the board's furniture and nobody's side; a sapling
-- belongs to whoever planted it, which is what lets a Nymph step into HER grove and not the company's,
-- and what lets a Heartwood bond ask whether its tree is still alive. It still stands in a lane like a
-- wall does, so a shove into it is a collision.
return {
    name = "Sapling",
    race = "object",
    tier = 0,
    plant = true,
    sprite = "assets/chars/sapling.png",
    stats = {
        health = 14, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 3, magicDefense = 3,
        movement = 0, -- rooted, the ordinary way
        speed = 0,    -- takes no turns
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 0, luck = 0,
    },
    startingItems = {},
}
