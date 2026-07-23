-- Cutpurse's Tally: the debuff-count math the shelf already owns (docs/classes.md, greed: "debuff-count
-- scaling"), lifted off Exploit Weakness and made a STANDING rule instead of a one-shot swing.
--
-- Exploit (data/items/ability/ability_exploit.lua) is a single ability that reads the target's
-- afflictions once, at the moment it is cast. This charm reads them on EVERY blow the bearer lands, for
-- the whole battle -- +`perDebuff` pre-mitigation damage for each debuff on whatever it is hitting. The
-- ability answers "spend a turn to punish an opening"; the charm answers "make my whole kit punish
-- openings", which is the difference between a spike and a build, and is exactly why greed's shelf
-- wanted the multiplier as a grid piece and not only as an action.
--
-- It reaches damage through the `damageBonusVs` hook (models/trait.lua -> Combat.dealDamage), a pure
-- query summed into the pre-mitigation base -- so the bonus rides the hover preview, and armor still
-- softens it, exactly like the attacker's own attack stat does.
--
-- The DEBUFFS list is the same one Exploit counts, kept in lockstep on purpose: the two items are the
-- ability and the charm reading of one idea, and a debuff that "opens a foe" for one must open it for
-- the other. Marked, Rooted, Crippled and the rest all count -- a party that sets the table before it
-- sits down (Exploit's own flavor) feeds this too. The bonus is a flat `perDebuff` rather than a forge
-- curve because the charm's scaling is the FIGHT, not the anvil: the more the party stacks, the harder
-- every one of the bearer's blows bites, which is a knob the player turns by playing rather than paying.
local DEBUFFS = {
    "status_poison", "status_burn", "status_acid", "status_mark", "status_blind", "status_cripple",
    "status_root", "status_stun", "status_freeze", "status_wet", "status_mired", "status_bleed",
    "status_exposed", "status_sundered",
}

return {
    name = "Cutpurse's Tally",
    description = "Your blows deal extra damage for every debuff already on the target.",
    perDebuff = 3, -- flat, pre-mitigation, per debuff on the struck foe
    damageBonusVs = function(ctx)
        local n = 0
        for _, id in ipairs(DEBUFFS) do
            if ctx.hasStatus(ctx.target, id) then n = n + 1 end
        end
        if n == 0 then return 0 end
        return (ctx.def.perDebuff or 3) * n
    end,
}
