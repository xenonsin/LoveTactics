-- A longbow, so it is drawn before it looses and reaches five tiles (docs/weapons.md). Its extra is that
-- the shaft does not stop: it lands as a three-tile line driving away from the archer, and it lands `raw`
-- -- no defense, no tag resist, nothing.
--
-- What the draw buys here is PENETRATION rather than reach, which is the family's own bargain pointed
-- somewhere new. Every other longbow spends its turn on one enormous arrow at one body; this spends it on
-- an arrow that goes through three of them and does not care what any of them are wearing.
--
-- It is the hunter's answer to heavy infantry, and the only `raw` weapon outside the knight's shelf
-- (data/items/weapon/weapon_mailpiercer.lua being the other). Against a rank of armoured men standing in
-- a corridor it is the best weapon in the game. Against three skirmishers in the open it is a poor
-- longbow that took a turn to draw.
--
-- The line runs from the archer through the target and beyond, so it wants the enemy stacked along the
-- shooting lane rather than spread across it -- which is exactly the formation heavy infantry adopt.
return {
    name = "Piercing Draw",
    description = "A drawn shaft that runs three tiles deep and ignores armour entirely.",
    flavor = "The Lodge's bowyers describe the arrow as 'unhelpful'. They have never explained who they mean it is unhelpful to.",
    sprite = "assets/items/piercing_draw.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    price = 460,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        channel = 2,
        cost = { stat = "stamina", amount = 11 },
        -- Well under the iron longbow's per body -- `raw` means all of it arrives, and three bodies may
        -- pay it. A raw shot at the family's usual weight would simply delete a rank.
        damage = { 6, 7, 7, 8, 9, 9, 10, 11, 12, 12, 13 },
        -- The line runs from the archer THROUGH the aimed cell: the arrow's own flight path continued.
        aoe = { shape = "line", length = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u, { raw = true }) -- defense and every tag resist skipped (Combat.mitigatedDamage)
            end
        end,
    },
}
