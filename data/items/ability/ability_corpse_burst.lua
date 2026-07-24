-- Corpse Burst: the Necromancer's other use for the dead. Where Raise Dead stands the fallen back up,
-- this UNMAKES them -- every corpse in a 3x3 is consumed, and the more of them go up, the harder the
-- blast that follows. A bloodied field is ammunition.
--
-- The damage is base + a share for each body spent (fx.consumeCorpse takes each off the field, unraisable
-- and unrevivable after), so it is at its weakest thrown into empty ground and at its worst thrown into a
-- charnel pit -- which is the read the discipline is built on: hold it until the killing has been done,
-- then turn the killing into more of itself. The corpses are COUNTED before they are consumed, so the
-- damage preview reads true (the count is a read-only sweep; the consume is the board-mutating half that a
-- dry run leaves inert). With no bodies in the blast it spends the mana for nothing rather than faulting --
-- there is simply nothing to detonate.
--
-- The blast catches allies standing in it too, exactly as Meteor Storm's does: it is thrown at GROUND,
-- and everything on that ground -- including a raised zombie of your own -- eats the same dark burst.
return {
    name = "Corpse Burst",
    description = "Consumes every corpse in the area and blasts the ground with dark power -- harder for each body spent.",
    flavor = "The Arcanum keeps a ledger of what a body is worth. It turns out to be worth roughly one more body.",
    sprite = "assets/items/ability_corpse_burst.png",
    type = "ability",
    tags = { "dark", "magical" },
    class = "mage",
    discipline = "necromancer", -- deeper cut of the shelf: buyable only once the necromancer gate is cleared
    price = 420,
    repRank = 4,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 5,
        requiresSight = true,
        speed = 6,
        cost = { stat = "mana", amount = 16 },
        aoe = { radius = 1, shape = "square" }, -- the 3x3 it sweeps for bodies and blasts
        damage = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 }, -- fx.amount: the base blast, before the bodies add to it
        effect = function(fx)
            -- Count first (a read-only sweep the preview can run truthfully), THEN consume: a dry run
            -- leaves the consume inert, so counting up front is what keeps the damage the tooltip shows
            -- equal to the damage the cast deals.
            local corpses = fx.corpsesIn()
            local n = #corpses
            if n == 0 then return end -- nothing to detonate; the mana is spent either way
            for _, corpse in ipairs(corpses) do fx.consumeCorpse(corpse) end
            local dmg = fx.amount + n * 6 -- each body spent adds to the blast
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u, { amount = dmg })
            end
        end,
    },
}
