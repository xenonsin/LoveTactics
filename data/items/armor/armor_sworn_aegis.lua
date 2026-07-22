-- The Knight's signature relic: the shield they swore their oath on. It carries the Knight's innate
-- guard (data/traits/oathward.lua) -- the trait now rides on this item, not on the character, and
-- reaches the unit through the grid exactly like any other item-granted reaction (models/trait.lua).
--
-- It is also the shield's own ANSWER, and the shield's whole character in one action: it does nothing
-- until she has done the wall's work -- weathered four blows -- and only then may it be loosed, a single
-- sweep that strikes and SHOVES every adjacent foe two tiles back (the knight's own displacement, her
-- mace's verb, turned on the whole ring). The conditional-signature system (Combat.unlockMet /
-- itemBlockReason): the slot stays greyed with a "Weather 4 blows (n/4)" badge until earned, then lights
-- up ready, and re-locks after each use. `hitTaken` counts only survived blows with a real attacker
-- (Combat.tally) -- exactly the wall's work -- and a locked signature is left out of the opening
-- initiative, so carrying it never slows her first turn. It can never lock her out of acting: her mace
-- and the rest of the grid are always there; this is the payoff for holding the line.
--
-- `bound = true` is the reusable lock (models/item.lua): it can never be moved off its cell, stowed,
-- given away, sold, or stolen -- only forged. The Knight's blueprint places it in the center of the
-- loadout grid, where it is the build-around the eight surrounding cells arrange themselves for.
--
-- No `class` and no `price`: no vendor stocks or buys it. It is upgraded at the Blacksmith like a
-- shield, its defense curve climbing with the forge.
return {
    name = "Sworn Aegis",
    description = "The first hit each turn on an adjacent ally is taken by you instead.",
    flavor = "The shield the oath was sworn on, and it never leaves your hand. A knight is the promise, not the steel.",
    sprite = "assets/items/sig_sworn_aegis.png",
    type = "armor", -- a shield: `bound` (not the type) is what locks it in place
    tags = { "signature", "shield" },
    class = "knight",
    bound = true,
    traits = { "trait_oathward" },
    bonus = { defense = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
    resist = { physical = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2 } },
    -- Defend brace: the knight's core stance, its +defense climbing as the shield is forged.
    waitBehavior = { kind = "defend", speed = 3, defense = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 } },
    -- The oath's answer (see the header): locked until she has weathered four blows, then a sweep that
    -- strikes and shoves the whole adjacent ring. A self-centred area cast -- friend and self spared.
    activeAbility = {
        description = "Strikes every adjacent foe and shoves them two tiles back.",
        target = "self",       -- centred on the wall itself; the aoe catches the ring around her
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 14 },
        unlock = { event = "hitTaken", count = 4, text = "Weather 4 blows" },
        aoe = { radius = 1, shape = "square" }, -- the eight tiles around her, corners included
        damage = { 10, 11, 12, 13, 15, 16, 17, 18, 20, 21, 22 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.damage(u)
                    fx.knockback(u, 2, { amount = fx.amount }) -- two tiles back; a stopped shove bruises
                end
            end
        end,
    },
}
