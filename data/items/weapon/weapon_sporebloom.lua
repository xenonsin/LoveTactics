-- Sporebloom: the Thurifer sets off one of its Puffers from where it stands, without the Puffer having
-- to walk there.
--
-- SELF-AIMED, and it picks the Puffer: of every Puffer on its own side, the one with the most foes beside
-- it. That Puffer is killed outright (a raw toll of its whole bar), so what goes off is its own death --
-- Spore Burst (trait_spore_burst), poison and Swoon on everything around it, its own folk included. The
-- Thurifer turns every Puffer on the board into a mine it can pull when the company bunches up, which is
-- why the right order against the mushroom folk is the one at the back first.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Sporebloom",
    description = "Bursts its own Puffer that has the most foes beside it, wherever it stands.",
    flavor = "It does not need them to get close. It only needs you to.",
    sprite = "assets/items/sporebloom.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "poison", "magical" },
    noSteal = true,
    activeAbility = {
        target = "self",
        support = false, -- aimed at its own feet, and a blow at the company (items_spec)
        range = 0,
        speed = 4,
        cost = { stat = "mana", amount = 8 },
        ai = {
            { priority = "high", act = "cast", when = { subject = "any_foe", test = "exists" } },
        },
        effect = function(fx)
            local user = fx.user
            local best, bestCount = nil, 0
            for _, p in ipairs(fx.combat.units) do
                if p.alive and p.side == user.side and p.char and p.char.id == "character_swooncap_puffer" then
                    local n = 0
                    for _, u in ipairs(fx.unitsNear(p.x, p.y, 1)) do
                        if u.alive and u.side ~= user.side then n = n + 1 end
                    end
                    if n > bestCount then best, bestCount = p, n end
                end
            end
            if not best then
                fx.log("action", string.format("%s shakes its cap, and nothing near a foe answers.", user.char.name or "It"))
                return
            end
            fx.flatDamage(best, best.char.stats.health.current, { "poison" })
        end,
    },
}
