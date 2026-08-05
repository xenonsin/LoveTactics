-- Counter/charge items (S: the `counter` contract). Three items on the shelf hold a purse they fill
-- over a fight and spend whole: the Gleaning Rod banks a charge per nearby spell, the Gleaner's Mantle
-- banks off the same broadcast and spends it as a ward, and the Reliquary of Tallies banks one per
-- comrade lost. All three declare `activeAbility.counter`, which reports what the purse currently
-- holds -- the one number the grid badge draws AND the block gate reads, so the two can never disagree.
--
-- The rule this pins: an empty purse is a refused cast, not a wasted turn. Combat.itemBlockReason
-- reports kind "empty" while the count is 0 (so the slot greys out and Combat.useItem declines), and
-- stops reporting it the moment the purse holds anything.
--
-- And the rule the last case pins, which is the one a purse can quietly fail: a banked purse belongs
-- to the LIVE board and not to the cursor. Both damage previews replay an ability's effect against the
-- real item table, so an effect that emptied itself with a direct `fx.item.charges = 0` would drain
-- the purse on every hover. fx.bankItem is inert in both dry runs; this proves it.

local Combat = require("models.combat")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

return {
    {
        name = "an empty Reliquary of Tallies is refused, and fills as comrades fall",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_amana", 2, 2,
                { isolate = "bare", items = { "utility_reliquary_of_tallies" }, stats = { mana = 40 } })
            local foe = Fixture.unit("character_bandit", 2, 4, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            local reliquary = Fixture.itemNamed(h.char, "utility_reliquary_of_tallies")
            local ab = reliquary.activeAbility

            assert(ab.counter(h, reliquary) == 0, "it opens empty -- nothing owed yet")
            local blocked = Combat.itemBlockReason(h, reliquary)
            assert(blocked and blocked.kind == "empty", "an empty reliquary is refused, kind 'empty'")

            Combat.tally(h, "allyDown", 2) -- two comrades lost
            assert(ab.counter(h, reliquary) == 2, "the purse now reads the two it is owed")
            assert(Combat.itemBlockReason(h, reliquary) == nil,
                "and with the mana to pay it, the cast is no longer refused")
        end,
    },
    {
        name = "an empty Gleaning Rod is refused; a charged one is not",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_mage", 2, 2,
                { isolate = "bare", items = { "utility_gleaning_rod" }, stats = { mana = 40 } })
            local foe = Fixture.unit("character_bandit", 2, 4, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            local rod = Fixture.itemNamed(h.char, "utility_gleaning_rod")
            local ab = rod.activeAbility

            assert(ab.counter(h, rod) == 0, "the rod starts dry")
            assert(Combat.itemBlockReason(h, rod).kind == "empty", "a dry rod is refused")

            -- Firing a dry rod does nothing: the gate declines it, so the target is untouched.
            local before = f.char.stats.health.current
            local ok, why = Combat.useItem(combat, h, rod, f.x, f.y)
            assert(not ok and why == "empty", "Combat.useItem declines the empty cast")
            assert(f.char.stats.health.current == before, "and the foe is untouched -- no wasted turn")

            rod.charges = 3
            assert(ab.counter(h, rod) == 3, "banked charges read straight off the item")
            assert(Combat.itemBlockReason(h, rod) == nil, "a charged rod is castable")
        end,
    },
    {
        -- The Gleaner's Mantle is the armour form of the same economy, and the case worth pinning is
        -- that it is SELF-CONTAINED: the trait that fills it and the ability that spends it are on the
        -- one item, so it is never inert for want of a second relic. Both sides of the field feed it.
        name = "the Gleaner's Mantle banks off both sides' spells and spends the bank as a ward",
        fn = function()
            local map = Fixture.new(8, 8)
            local wearer = Fixture.unit("character_mage", 2, 2,
                { isolate = "bare", items = { "armor_gleaners_mantle" }, stats = { mana = 60, health = 200 } })
            local shieldmate = Fixture.unit("character_knight", 3, 2,
                { isolate = "bare", stats = { health = 200 } })
            local ally = Fixture.unit("character_mage", 2, 3,
                { isolate = "bare", items = { "ability_fire_bolt" }, stats = { mana = 60, health = 200 } })
            local foe = Fixture.unit("character_mage", 2, 4,
                { isolate = "bare", items = { "ability_fire_bolt" }, stats = { mana = 60, health = 200 } })
            local combat = Combat.new(map, { wearer, shieldmate, ally }, { foe })
            local w, mate, a, f = combat.units[1], combat.units[2], combat.units[3], combat.units[4]
            local mantle = Fixture.itemNamed(w.char, "armor_gleaners_mantle")
            local ab = mantle.activeAbility

            assert(ab.counter(w, mantle) == 0, "the hem starts empty")
            assert(Combat.itemBlockReason(w, mantle).kind == "empty", "and an empty hem is refused")

            -- Its own wearer's working never feeds it (Trait.onAnyCast skips the caster) -- these are
            -- other people's spells, which is the whole conceit.
            assert(Fixture.strike(combat, a, f, "ability_fire_bolt"), "an ally works a spell beside it")
            assert(ab.counter(w, mantle) == 1, "the party's own caster fills it")
            assert(Fixture.strike(combat, f, a, "ability_fire_bolt"), "and so does the enemy's")
            assert(ab.counter(w, mantle) == 2, "BOTH sides feed it -- that is the mechanic, not a leak")

            -- The purse belongs to the board, not to the cursor: the inventory tooltip replays this very
            -- effect against the real mantle on every hover frame.
            local hover = Combat.abilityOutput(w, mantle)
            local named = false
            for _, s in ipairs((hover and hover.statuses) or {}) do
                if s.id == "status_magical_barrier" then named = true end
            end
            assert(named, "the tooltip names the ward it would raise")
            assert(mantle.charges == 2, "and hovering it does not spend the bank")

            assert(Fixture.strike(combat, w, w, mantle), "the hem is loosed")
            assert(mantle.charges == 0, "which empties the purse entirely")
            assert(Status.has(w, "status_magical_barrier"), "the wearer is warded")
            assert(Status.has(mate, "status_magical_barrier"), "and so is the ally standing beside them")
            assert(Status.has(a, "status_magical_barrier"), "the whole adjacent ring, in fact")
            assert(not Status.has(f, "status_magical_barrier"), "the enemy who helped fill it gets nothing")
            assert(Status.get(w, "status_magical_barrier").magnitude == 1,
                "two charges buys one warded blow -- the floor, since a ward cannot negate harder")
            assert(Combat.itemBlockReason(w, mantle).kind == "empty", "and the spent hem is refused again")
        end,
    },
    {
        -- Coverage is the only axis a ward can grow along, so the bank buys blows rather than size:
        -- three charges to the blow (see status_magical_barrier on why size is not an option).
        name = "the Gleaner's Mantle spends three charges per blow it wards",
        fn = function()
            local map = Fixture.new(8, 8)
            local wearer = Fixture.unit("character_mage", 2, 2,
                { isolate = "bare", items = { "armor_gleaners_mantle" }, stats = { mana = 60, health = 200 } })
            local foe = Fixture.unit("character_bandit", 5, 5, { isolate = "bare" })
            local combat = Fixture.combat(map, wearer, foe)
            local w = combat.units[1]
            local mantle = Fixture.itemNamed(w.char, "armor_gleaners_mantle")

            mantle.charges = 9 -- a full Arcanum duel's worth
            assert(Fixture.strike(combat, w, w, mantle), "the hem is loosed on a fat purse")
            assert(Status.get(w, "status_magical_barrier").magnitude == 3,
                "nine banked charges stand for three magical blows")
        end,
    },
    {
        -- The Long Count wears a counter too, but a SCALING one, not a purse: it reads the turns its
        -- bearer has taken and grows the blow by them (weapon_long_count). `counterGates = false`, so a
        -- reading of 0 is a floor to build from -- the cast is NEVER refused for an empty count, unlike
        -- the two purses above. The badge shows the tally; the swing still lands on turn one.
        name = "the Long Count's counter reads turns taken and never refuses an empty count",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "weapon_long_count" }, stats = { stamina = 40 } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            local blade = Fixture.itemNamed(h.char, "weapon_long_count")
            local ab = blade.activeAbility

            assert(ab.counter(h, blade) == 0, "it opens at zero -- no turns taken yet")
            -- The whole point of counterGates = false: an empty count is castable, not greyed out.
            assert(Combat.itemBlockReason(h, blade) == nil,
                "and a zero count does NOT refuse the swing -- the first swing is still a real swing")

            Combat.tally(h, "turnTaken", 5) -- five turns weathered
            assert(ab.counter(h, blade) == 5, "the badge now reads the five turns it has outlasted")
            assert(Combat.itemBlockReason(h, blade) == nil, "and it was never gated on the count")
        end,
    },
    {
        -- The readout the slot badge and the tooltip row both draw off (Combat.itemChargeReadout),
        -- for the OTHER kind of banked resource: a shared pool rather than a per-item purse. Pinned
        -- here because a pool is banked in one file and spent in another, and until this readout
        -- existed neither of them put the number on screen at all.
        name = "a charge pool reports its count, its merged ceiling and its name for the UI to quote",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_rowan", 2, 2,
                { isolate = "bare", items = { "ability_defiant_stand", "utility_crowds_favour" } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            local stand = Fixture.itemNamed(h.char, "ability_defiant_stand")
            local favour = Fixture.itemNamed(h.char, "utility_crowds_favour")

            local n, max, label = Combat.itemChargeReadout(h, stand)
            assert(n == 0 and label == "Defiance", "an unblooded Champion holds no Defiance, and it is named")
            assert(max == 8, "and the ceiling is the MERGED one -- Crowd's Favour deepens the pool past the 6 " ..
                "Defiant Stand declares, so quoting one file's figure would understate what it banks into")

            -- The passive charm has no ability at all, which is exactly the case an `if activeAbility`
            -- gate used to hide: its whole job is to accrue, so its count has to read off the slot.
            assert(favour.activeAbility == nil, "Crowd's Favour is a pure banker")
            local fn2, fmax = Combat.itemChargeReadout(h, favour)
            assert(fn2 == 0 and fmax == 8, "and it quotes the same pool from the passive side")

            Combat.tally(h, "hitTaken", 3)
            assert(Combat.itemChargeReadout(h, stand) == 3, "three weathered blows read back off both items")
            assert(Combat.itemChargeReadout(h, favour) == 3, "-- it is one pool, not two")
        end,
    },
    {
        -- Chi is the one pool no item can declare (its source is the body -- Combat.CHARGE_DEFS), so a
        -- fist ability names the pool it SPENDS instead. Without that the monk's whole kit asks the
        -- player to decide off a number nothing on screen was showing.
        name = "a chi spender names the pool it reads, so the monk's count is quotable off the slot",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_monk", 2, 2,
                { isolate = "bare", items = { "ability_asura_strike" }, stats = { stamina = 40 } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            local asura = Fixture.itemNamed(h.char, "ability_asura_strike")

            assert(Combat.itemChargeKey(asura) == "chi", "the blow names the pool it spends")
            local n, max, label = Combat.itemChargeReadout(h, asura)
            assert(n == 0 and max == Combat.CHI_MAX and label == "Chi",
                "and the readout is the monk's own pool, at the engine's ceiling")

            Combat.tally(h, "unarmedHit", 4)
            assert(Combat.itemChargeReadout(h, asura) == 4, "four landed fists read back as four chi")
        end,
    },
    {
        -- The rule, swept rather than spot-checked: an item that accrues must be able to say how much
        -- it holds. Every declared pool and every ad-hoc bank on the shelf has to surface through one
        -- of the two readouts the UI draws -- `activeAbility.counter` (a per-item purse) or
        -- Combat.itemChargeKey (a shared pool). A new banker that forgets fails here rather than
        -- shipping a resource the player is asked to decide about and never shown.
        name = "every item that banks a resource can report its count",
        fn = function()
            local Item = require("models.item")
            local Trait = require("models.trait")
            local missing = {}
            for id, def in pairs(Item.defs) do
                local ab = def.activeAbility
                -- The three ways a blueprint declares that it accrues: a shared pool it opens or
                -- deepens, a pool it only spends (chi), and a capped stacking trait it grants.
                local banks = def.charge ~= nil or (ab and ab.spendsCharge ~= nil)
                for _, tid in ipairs(def.traits or {}) do
                    local tdef = Trait.defs[tid]
                    if tdef and tdef.maxStacks then banks = true end
                end
                -- ...and the three readouts the UI draws one from. A capped trait is its own readout:
                -- Trait.stackReadout finds it off the item without the blueprint declaring anything.
                local shows = (ab and ab.counter ~= nil) or Combat.itemChargeKey(def) ~= nil
                    or banks -- a maxStacks trait is readable by construction
                if def.charge and not (ab and ab.counter) and not Combat.itemChargeKey(def) then
                    shows = false
                end
                if banks and not shows then missing[#missing + 1] = id end
            end
            assert(#missing == 0,
                "these bank a resource with no count for the UI to draw: " .. table.concat(missing, ", "))
        end,
    },
    {
        -- The schema sweep above catches a DECLARED resource. It cannot catch the other kind: a blow
        -- that multiplies itself by a running tally reads that tally inside its effect body, where
        -- nothing is introspectable -- which is exactly how the Reaper's Due and the Last Word shipped
        -- scaling off an invisible number while the Long Count, doing the same thing, displayed one.
        --
        -- So this reads the SOURCE. Crude on purpose: a data file that so much as mentions a running
        -- count has to also declare a readout for it. A false positive is cheap to answer (declare the
        -- counter, which the item wanted anyway) and the failure it prevents is a resource the player
        -- is asked to do arithmetic on and never shown.
        name = "an item that reads a running count in its effect also declares one for the UI",
        fn = function()
            local Item = require("models.item")
            local ACCRUAL = { "tallyCount", "chargePool" }
            local missing = {}
            for _, dir in ipairs(love.filesystem.getDirectoryItems("data/items")) do
                local path = "data/items/" .. dir
                if love.filesystem.getInfo(path).type == "directory" then
                    for _, f in ipairs(love.filesystem.getDirectoryItems(path)) do
                        local id = f:match("^(.+)%.lua$")
                        local def = id and Item.defs[id]
                        if def then
                            local src = love.filesystem.read(path .. "/" .. f) or ""
                            local reads = false
                            for _, word in ipairs(ACCRUAL) do
                                if src:find(word, 1, true) then reads = true end
                            end
                            local ab = def.activeAbility
                            local shows = (ab and ab.counter ~= nil) or Combat.itemChargeKey(def) ~= nil
                            if reads and not shows then missing[#missing + 1] = id end
                        end
                    end
                end
            end
            assert(#missing == 0, "these scale off a running count but declare no readout: " ..
                table.concat(missing, ", "))
        end,
    },
    {
        -- The two weapons the audit caught: both multiply their blow by a running tally the engine was
        -- already keeping, and neither put the number on screen. They are pinned together because the
        -- bug was the same one twice -- a weapon whose whole identity is a count, wearing none.
        name = "a tally-scaled weapon quotes the count its damage is multiplied by",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_rowan", 2, 2,
                { isolate = "bare", items = { "weapon_reapers_due", "weapon_last_word" } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            local axe = Fixture.itemNamed(h.char, "weapon_reapers_due")
            local bow = Fixture.itemNamed(h.char, "weapon_last_word")

            assert(axe.activeAbility.counter(h, axe) == 0, "the Reaper's Due opens on an empty count")
            assert(bow.activeAbility.counter(h, bow) == 0, "and so does the Last Word, with the party intact")
            -- Neither is a purse: an empty count is the floor they swing from, never a refused cast.
            assert(Combat.itemBlockReason(h, axe) == nil, "an unblooded axe still swings")
            assert(Combat.itemBlockReason(h, bow) == nil, "and an intact party still shoots")

            Combat.tally(h, "kill", 3)
            Combat.tally(h, "allyDown", 2)
            assert(axe.activeAbility.counter(h, axe) == 3, "three kills read back off the axe")
            assert(bow.activeAbility.counter(h, bow) == 2, "two fallen read back off the bow")
        end,
    },
    {
        -- A passive charm has no ability to hang a counter on, so the count comes off the TRAIT. The
        -- Butcher's Tally is the case that named the problem: a strap notched once per body, showing
        -- no notches.
        name = "a stacking passive charm reports its banked stacks and its ceiling",
        fn = function()
            local map = Fixture.new(8, 8)
            local Trait = require("models.trait")
            local hero = Fixture.unit("character_rowan", 2, 2,
                { isolate = "bare", items = { "utility_butchers_tally" } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            local strap = Fixture.itemNamed(h.char, "utility_butchers_tally")

            assert(strap.activeAbility == nil, "it is a pure passive -- there is no ability to count on")
            local n, max, label = Trait.stackReadout(h, strap)
            assert(n == 0 and max == 5 and label == "Blood Fever",
                "so the readout comes off the trait: no bodies yet, out of the five it can hold")

            -- The stack is what the trait banks; the readout has to follow it rather than re-derive it.
            for _, t in ipairs(h.traits or {}) do
                if t.item == strap then t.stacks = 3 end
            end
            assert(Trait.stackReadout(h, strap) == 3, "three bodies banked read straight back off the strap")
        end,
    },
    {
        name = "an unaffordable empty purse is told about the mana first, not the empty",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_amana", 2, 2,
                { isolate = "bare", items = { "utility_reliquary_of_tallies" }, stats = { mana = 0 } })
            local foe = Fixture.unit("character_bandit", 2, 4, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            local reliquary = Fixture.itemNamed(h.char, "utility_reliquary_of_tallies")

            local blocked = Combat.itemBlockReason(h, reliquary)
            assert(blocked and blocked.kind == "cost",
                "affordability is the more fixable thing, so it is reported ahead of the empty purse")
        end,
    },
}
