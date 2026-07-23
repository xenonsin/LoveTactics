-- Drowsing Air: the hunter puts a whole quarter of the field to sleep. Everyone in a wide square goes
-- under -- and any hit at all, from anyone, wakes whoever it landed on and hands back the time they
-- had not yet served.
--
-- NOT A SETUP FOR FOCUSED FIRE. It is the exact opposite of one, and everything about how it should be
-- played follows from that. Sleep breaks on damage (see data/status/status_sleep.lua, which owns the
-- rule), so this spell does not say "kill these three" -- it says "these three are not part of the
-- fight for a while, as long as you leave them completely alone".
--
-- Which is what makes it the largest-reaching thing the Lodge sells and still a fair spell: it splits
-- a battle in half. Sleep the flank, kill the middle, come back for the flank. A party that then
-- splashes a fireball across the sleeping half has undone the whole cast and learned the rule in the
-- same beat -- and so has one that leaves a Burn ticking on somebody before casting it.
--
-- IT SLEEPS YOUR OWN LINE TOO. A wide unsided square dropped over a melee puts the party's knight
-- under alongside the enemy's, and the knight wakes the instant anybody hits them -- which, in a melee,
-- is immediately. Cast it where your people are not.
--
-- ADJACENCY: a `bow` beside it, like the rest of this shelf. The gate is doing real work here rather
-- than gesturing at flavour: a hunter who sleeps half the board and cannot shoot the other half has
-- bought three turns of quiet and nothing to do with them.
return {
    name = "Drowsing Air",
    description = "Puts everyone in a wide square under; any hit wakes the one it lands on.",
    flavor = "Half the wood goes quiet. The Lodge is very clear that this is a courtesy, and revocable.",
    sprite = "assets/items/ability_drowsing_air.png",
    type = "ability",
    tags = { "arcane", "magical" },
    class = "hunter",
    price = 420,
    repRank = 4,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 5,
        requiresSight = true,
        speed = 5,
        channel = 3,
        cost = { { stat = "mana", amount = 14 }, { stat = "stamina", amount = 8 } },
        support = true, -- it lands no damage at all, and damage is the thing that undoes it
        aoe = { radius = 2, shape = "square" },
        requiresAdjacent = { tag = "bow" },
        effect = function(fx)
            -- Everyone caught, the caster's own side included: fx.aoeUnits is the whole footprint. A
            -- version that spared allies would be strictly better and much less interesting, and it
            -- would also be a lie about what the spell is -- the air does not know whose it is.
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user then
                    fx.applyStatus(u, "status_sleep", { duration = 14 + fx.level })
                end
            end
        end,
    },
}
