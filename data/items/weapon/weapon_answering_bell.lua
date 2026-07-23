-- A mace, so it shoves (docs/weapons.md) -- and it is the only one that shoves without being swung. It
-- carries `trait_shield_shove` (the Bulwark Shield's reflex), so a melee attacker is driven two tiles back
-- for having closed at all.
--
-- Quest-only: `class` with no `price`.
--
-- The family's verb, moved onto the reflex half of the game. Every other mace here spends the wielder's
-- turn to decide where somebody stands; this one spends the ENEMY's turn to do it, and gives the wielder
-- their own turn back. What it produces is a body nobody can stay next to: close on it, get shoved, spend
-- next turn closing again.
--
-- It matters that the reflex was already in the game on a shield (data/items/armor/armor_bulwark_shield.lua)
-- rather than being minted here. The two together are the point: the Bulwark spends your Wait to hold a
-- tile, and this holds it while you swing. A knight carrying both shoves on the answer AND on the brace,
-- which is a genuinely different way to hold a doorway than anything the shelf could do before.
--
-- Priced by the trait's own declared cost rather than by the swing rule, because a shove is not a swing
-- -- there is no weapon in the motion to read a price off (docs/weapons.md, "Pricing a triggered
-- reflex"). It still escalates per answer in a round like everything else that answers.
return {
    name = "The Answering Bell",
    description = "Drives the target back two tiles -- and drives back anyone who strikes you in melee, too.",
    flavor = "It is not that it hits back. It is that there is, quite suddenly, more room.",
    sprite = "assets/items/answering_bell.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    traits = { "trait_shield_shove" }, -- the whole extra; see armor_bulwark_shield for what it costs
    class = "knight",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 9 },
        -- Under an iron mace's: the reflex is the rest, and a weapon that both answers and hits full
        -- would make standing next to it strictly worse than any other tile on the board.
        damage = { 6, 6, 7, 8, 8, 9, 10, 10, 11, 12, 13 },
        effect = function(fx)
            fx.damage(fx.target, { knockback = { distance = 2, amount = fx.amount } })
        end,
    },
}
