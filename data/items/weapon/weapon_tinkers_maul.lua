-- A hammer, so it stuns and is ponderous (docs/weapons.md). Its extra is that it OPENS things: the blow
-- strips the guards a braced body is hiding behind -- Defending, a physical barrier, a magical one -- and
-- then stuns whatever is left standing there.
--
-- The entry-rank alternative to the iron hammer, and the answer to the one enemy a hammer is otherwise
-- bad against. A hammer buys its stun with its own tempo (speed 7), which is a terrible trade against a
-- foe that spends its turns bracing: you pay a turn and a half to land a blow on somebody whose whole
-- plan was to be hit. This one makes bracing the mistake.
--
-- Deliberately the weakest hammer on the shelf. It is a can-opener, and it should be swung at the shield
-- wall so that everything else in the party can swing at what is behind it.
return {
    name = "Tinker's Maul",
    description = "Strips a foe's brace and wards, then stuns them. Hits softly -- what it is for is opening things.",
    flavor = "Every apprentice is told it is for dressing plate. Every journeyman finds out what it is really for.",
    sprite = "assets/items/tinkers_maul.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2, -- a two-handed maul, as every hammer is
    class = "fighter",
    price = 200,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7, -- the family's ponderous tempo: the stun is still bought with your own turn
        cost = { stat = "stamina", amount = 10 },
        -- Half an iron hammer's. What it removes is worth more than what it deals.
        damage = { 6, 6, 7, 8, 8, 9, 10, 10, 11, 12, 13 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            -- Stripped BEFORE the blow, or the barrier this weapon exists to remove would eat the very
            -- hit that was supposed to remove it.
            fx.clearStatus(t, "status_defending")
            fx.clearStatus(t, "status_physical_barrier")
            fx.clearStatus(t, "status_magical_barrier")
            fx.clearStatus(t, "status_splitglass")
            fx.damage(t, { inflicts = "status_stun" })
        end,
    },
}
