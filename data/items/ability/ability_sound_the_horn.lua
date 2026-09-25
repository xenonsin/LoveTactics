-- SOUND THE HORN: "the dwarves came out" (round 3, 2026-09-24). Once a fight, the Dwarf Hornblower's horn
-- lends every dwarf on its side one more tile of movement for its next turn (status_horn_call). A cooldown
-- longer than any fight is how "once" is said here, as every per-battle shout in the tree says it.
return {
    name = "Sound the Horn",
    description = "Once a fight: every dwarf on your side moves 1 more tile on its next turn.",
    flavor = "It is not a signal. Every dwarf in earshot already knew what to do; the horn is to let the rest of you know.",
    sprite = "assets/items/ability_sound_the_horn.png",
    type = "ability",
    tags = { "rally" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        support = true,
        cooldown = 9999,
        effect = function(fx)
            local Trait = require("models.trait")
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 99)) do
                if u.alive and u.side == fx.user.side and Trait.has(u, "trait_inheritance") then
                    fx.applyStatus(u, "status_horn_call")
                end
            end
        end,
    },
}
