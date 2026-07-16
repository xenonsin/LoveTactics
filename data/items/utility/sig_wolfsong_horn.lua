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
-- far fiercer than any grunt. It answers no reservation but a blood-price, and the price is charged
-- when the Spirit DIES, not when it is called: its `blood_price` trait takes half the archer's
-- remaining health the moment it falls (data/traits/blood_price.lua).
--
-- Both calls share one throat. The companion holds the horn's `activeSummon` claim from the opening
-- bell (models/trait.lua), so the true call is refused for as long as the wolf at her side is alive,
-- and the Spirit holds it after that. One creature at a time, always: the horn opens the battle spent,
-- and only a dead wolf buys the right to sound it in earnest.
--
-- No `class`/`price`: no vendor stocks or buys it. Forged at the Blacksmith, its speed curve rising.
return {
    name = "Wolfsong Horn",
    description = "Raised beside a wolf; it still comes when the horn sounds. You start each battle " ..
        "with it at your side. Once it falls, sound the horn in earnest to call the Wolfsong Spirit -- " ..
        "whose own death costs you half your remaining health.",
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
        -- The call itself takes nothing: one spirit at a time (fx.summon stamps item.activeSummon),
        -- scaled by the horn's forge level, and its own blood_price trait collects when it falls. A
        -- spirit that dies on the tile it was called to (a trap, a fire) bills the archer immediately --
        -- it drew breath and lost it, which is exactly what the price is for.
        effect = function(fx)
            fx.summon("wolfsong_spirit", fx.tx, fx.ty,
                { scaling = { health = 2, damage = 0.5 }, amount = 8 + fx.level })
        end,
    },
}
