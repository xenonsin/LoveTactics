-- SUCCESSION: what a fallen body hands on (2026-09-26, "The Orcs of Wrath"). Two rules use it:
--
--   THE STRONGEST LEADS   the orc Warchief (data/traits/trait_the_strongest_leads.lua): when he falls, the
--                         most-Proven orc on his side (ties: most health) takes his place -- it heals half its
--                         health and takes up his Presence and this rule, so the fight goes on under a new head
--   THE ABILITY           his second drop (data/items/ability/ability_the_strongest_leads.lua), on Keno's note:
--                         "a separate ability that transfers this buff to the next living just like the orc
--                         chief". Cast ahead of time; if you then fall, every boon you hold passes to the living
--                         ally with the most health, who heals half its health.
local Status = require("models.status")

local Succession = {}

Succession.HEAL = 0.5

-- The living, on-board ally of `fallen` a succession would pass to. `rank(u)` orders the candidates (higher
-- wins); ties fall to current health.
function Succession.heir(combat, fallen, rank)
    local Combat = require("models.combat")
    local best, bestRank, bestHp
    for _, u in ipairs(combat.units or {}) do
        if u ~= fallen and u.alive and u.side == fallen.side and not Combat.isOffTile(u)
            and not u.summoner and (u.char and (u.char.tier or 1) > 0) then
            local r = rank and rank(u) or 0
            local hp = u.char.stats.health.current or 0
            if not best or r > bestRank or (r == bestRank and hp > bestHp) then
                best, bestRank, bestHp = u, r, hp
            end
        end
    end
    return best
end

-- Is status instance `s` a boon a succession hands on? Buffs only: nothing done TO the body (a debuff), and
-- nothing that is the succession's own promise or the body's state of having fallen.
local SKIP = { status_downed = true, status_succession = true, status_spectating = true }
local function isBoon(s)
    return s and s.def and not s.def.debuff and not SKIP[s.id] and not s.def.injury
end

-- Pass every boon `from` wears to `heir`, at the strength and time it had left. Returns how many passed.
function Succession.passBoons(combat, from, heir)
    local n = 0
    for _, s in ipairs(from.statuses or {}) do
        if isBoon(s) then
            Status.apply(combat, heir, s.id, {
                magnitude = s.magnitude,
                duration = s.remaining,
                statBonus = s.statBonus,
            })
            n = n + 1
        end
    end
    return n
end

-- Heal `heir` for Succession.HEAL of its max health.
function Succession.raise(combat, heir)
    local Combat = require("models.combat")
    local amount = math.floor(Combat.unreservedMax(heir.char, "health") * Succession.HEAL + 0.5)
    Combat.applyHeal(combat, heir, amount)
end

return Succession
