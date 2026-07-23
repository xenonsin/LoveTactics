-- Poacher's Kris: the Poacher (rogue x hunter) opens with a snare and closes with this. A dagger, so it
-- bleeds like every dagger (docs/weapons.md) -- but its EXTRA is what it does to a foe that cannot move:
-- half the swing's power again goes through a Rooted body, the way the Kingsblood puts it through a
-- bleeding one. Pair it with the Bolas (data/items/ability/ability_bolas.lua): pin, then collect.
--
-- Home shelf is the Undercroft (`class = "rogue"`, its bleed tally), and the discipline puts it on the
-- Lodge's shelf too once Poacher is unlocked -- a rogue blade on a hunter's rack, which is the point.
return {
    name = "Poacher's Kris",
    description = "Inflicts Bleed, and strikes far harder into a Rooted foe.",
    flavor = "The snare is the Lodge's. The knife that follows is not.",
    sprite = "assets/items/weapon_poachers_kris.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    class = "rogue",
    discipline = "poacher", -- rogue x hunter; the Snare-execute mechanic's first stock
    price = 220,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, like every dagger
        cost = { stat = "stamina", amount = 5 },
        damage = { 6, 6, 7, 8, 8, 9, 10, 10, 11, 12, 13 },
        effect = function(fx)
            -- A Rooted foe cannot flinch away from the point: half the swing again goes straight in.
            -- Read on the target as it stands, so it rewards a snare already set (by the Bolas, a trap,
            -- or an ally's Root), not the blade for a condition it did not make.
            local pinned = fx.hasStatus(fx.target, "status_root")
            local bonus = pinned and math.floor(fx.amount * 0.5) or 0
            fx.damage(fx.target, { amount = fx.amount + bonus })
            fx.applyStatus(fx.target, "status_bleed") -- daggers bleed (docs/weapons.md)
        end,
    },
}
