-- BANNER OF THE MOUNTAIN: the Dwarf Hornblower's standard (round 3, 2026-09-24, "The Dwarves of Greed").
-- The Rally Banner's own machinery (data/items/ability/ability_rally_banner.lua) -- a destructible banner
-- planted on a tile, holding a zone open while it stands -- cut to the dwarves: the zone reaches TWO
-- tiles, and what it grants is Under the Banner (+2 Damage) rather than Inspiration.
--
-- The banner decides where the dwarf line wants to fight, and it is a priority kill: when it falls, the
-- zone goes with it (Hazard.place's `owner`). Creature kit on a bodied thing -- the standard is the
-- Hornblower's office, not a piece the company loots.
return {
    name = "Banner of the Mountain",
    description = "Plants a destructible banner: dwarves within 2 tiles of it gain Damage while it stands.",
    flavor = "Every hall under the Mountain flies the same colours. Nobody alive remembers which one flew them first.",
    sprite = "assets/items/ability_banner_of_the_mountain.png",
    type = "ability",
    tags = { "banner", "rally" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 5,
        support = true,
        cooldown = 20,
        cost = { stat = "stamina", amount = 10 },
        effect = function(fx)
            if fx.unitAt(fx.tx, fx.ty) then return end
            local banner = fx.summon("character_banner", fx.tx, fx.ty, {
                control = "none", timeless = true, scaling = { health = 3 }, amount = fx.level,
            })
            if banner and banner.alive then
                for dy = -2, 2 do
                    for dx = -2, 2 do
                        fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_mountain_banner", { owner = banner })
                    end
                end
            end
        end,
    },
}
