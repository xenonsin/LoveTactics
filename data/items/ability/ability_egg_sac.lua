-- EGG SAC: the Larder Mother's brood. Two Spiderlings hatch beside her, but only while fewer than four
-- of hers are alive -- counted off the board the way the Standing Stone counts its totems, since a
-- summon claim is one body per item and this lays two.
--
-- AND IT BURSTS AT HALF HEALTH, for free: `phases` on this item, read by trait_boss_phases, hatch two
-- more on the beat she Moults (utility_moult) -- so her half-health turn is one event, not two.
--
-- The brood carries Engorge (utility_brood_hunger): when a sibling falls near one, the survivor feeds.
local CAP = 4
local HATCH = 2

local function broodOf(fx)
    local n = 0
    for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
        if u.alive and u.summoner == fx.user and u.char and u.char.id == "character_spiderling" then n = n + 1 end
    end
    return n
end

return {
    name = "Egg Sac",
    description = "Hatches two Spiderlings beside the caster, up to four alive. At half health it bursts for two more.",
    flavor = "It is not a nest. A nest is somewhere you come back to.",
    sprite = "assets/items/ability_egg_sac.png",
    type = "ability",
    class = "creature",
    tags = { "beast", "summon" },
    noSteal = true,
    traits = { "trait_boss_phases" },
    phases = {
        { at = 0.5, responses = {
            { kind = "summon", id = "character_spiderling", count = 2 },
            { kind = "log", text = "The egg sac splits." },
        } },
    },
    activeAbility = {
        target = "self",
        range = 0,
        support = false,
        speed = 6,
        cost = { stat = "stamina", amount = 14 },
        effect = function(fx)
            local room = math.min(HATCH, CAP - broodOf(fx))
            for _ = 1, room do
                local x, y = fx.openTileNear(fx.user.x, fx.user.y)
                if not x then break end
                fx.summon("character_spiderling", x, y, { noClaim = true })
            end
        end,
    },
}
