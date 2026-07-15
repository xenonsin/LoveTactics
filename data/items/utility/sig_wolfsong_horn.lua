-- The Archer's signature relic: the horn she was given the day the wolf first answered it. It carries
-- her innate companion (data/traits/wolf_companion.lua) -- a wolf fields itself at her side at the
-- opening bell, free of any mana reservation, distinct from the Summon Wolf ability any character can
-- carry. The trait now lives on this item and reaches her through the grid (models/trait.lua).
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. Her
-- blueprint sits it in the center of the loadout grid as the build-around.
--
-- Beyond the free companion, the horn holds a TRUE call (activeAbility): a full-throated blast that
-- summons the Wolfsong Spirit (data/characters/wolfsong_spirit.lua) -- the great wolf behind the pack,
-- far fiercer than any grunt. It answers no reservation but a blood-price: the call costs the archer
-- HALF her current health, paid straight out of the flesh (no armor softens it, and it can never drop
-- her below 1). One spirit at a time, sustained by her like any summon. So the horn is two things at
-- once: a free wolf every battle, and a desperate, self-wounding summon when the pack is not enough.
--
-- No `class`/`price`: no vendor stocks or buys it. Forged at the Blacksmith, its speed curve rising.
return {
    name = "Wolfsong Horn",
    description = "Raised beside a wolf; it still comes when the horn sounds. You start each battle " ..
        "with it at your side. Sound it in earnest to call the Wolfsong Spirit -- at the cost of half your health.",
    sprite = "assets/items/sig_wolfsong_horn.png",
    type = "utility", -- a horn: `bound` (not the type) is what locks it in place
    tags = { "signature" },
    bound = true,
    traits = { "wolf_companion" },
    bonus = { speed = { 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 } }, -- levels 0..10
    activeAbility = {
        target = "tile", -- aim an empty tile beside you; the spirit springs up there
        range = 1,
        speed = 6,
        effect = function(fx)
            -- One spirit at a time (fx.summon stamps item.activeSummon), scaled by the horn's forge level.
            local spirit = fx.summon("wolfsong_spirit", fx.tx, fx.ty,
                { scaling = { health = 2, damage = 0.5 }, amount = 8 + fx.level })
            -- The blood-price is paid only for a spirit that actually drew breath -- a wolf that dies on
            -- the tile it was called to (a trap, a fire) never took the summoner's blood with it.
            if spirit and spirit.alive then
                local hp = fx.user.char.stats.health
                local toll = math.floor((hp.current or 0) * 0.5) -- half of CURRENT health; never lethal
                if toll > 0 then
                    fx.drain(fx.user, "health", toll)
                    fx.log("damage", string.format("%s pays the blood-price: %d health.",
                        (fx.user.char and fx.user.char.name) or "The summoner", toll))
                end
            end
        end,
    },
}
