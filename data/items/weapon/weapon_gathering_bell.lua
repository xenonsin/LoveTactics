-- A mace, so it displaces (docs/weapons.md) -- and it is the one mace that displaces the wrong way. The
-- hooked head DRAGS: the target is pulled a tile toward the wielder instead of driven away, and the
-- collision, if there is one, happens against your own line.
--
-- The family's whole premise is "you are not buying the damage, you are buying where they end up," and
-- every other mace on the rack reads that as *away*. This reads it as *here*. Which turns out to be a
-- completely different weapon, because everything the party owns that is priced around adjacency --
-- a sword's parry, an axe's arc, a censer's smoke, `covers`, Formation Fighter -- wants the enemy
-- gathered rather than scattered.
--
-- It is the mace for a party that has already won the positioning and wants the enemy to stop running.
-- Against a caster line it is close to unfair: pull the mage out of its own back rank and into the
-- middle of your melee. Against a wall of heavy infantry that WANTED to be adjacent, it is a worse
-- Iron Mace.
--
-- The obvious way to lose with it: dragging a champion into the middle of your own squishy line, which
-- is precisely the thing every other mace on the shelf exists to prevent.
return {
    name = "The Gathering Bell",
    description = "Hooks the target and drags them a tile toward you rather than driving them away.",
    flavor = "Every other mace in the armoury answers the question of where they should go. This one has a different question.",
    sprite = "assets/items/gathering_bell.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    class = "knight",
    price = 520,
    repRank = 4,
    activeAbility = {
        target = "enemy",
        range = 2, -- a hook has reach the family does not: it has to be able to fetch something
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = { 7, 8, 9, 9, 10, 11, 12, 13, 13, 14, 15 },
        effect = function(fx)
            fx.damage(fx.target)
            -- Pulled AFTER the blow rather than folded into it, unlike every shove on the shelf. A shove
            -- rides in the damage so a killing hit still throws the body -- but there is no reason to
            -- drag a corpse toward your own line, and `fx.pull` on a dead body would be a wasted call.
            if fx.target.alive then
                fx.pull(fx.target) -- Combat.pull draws it one step toward the wielder
            end
        end,
    },
}
