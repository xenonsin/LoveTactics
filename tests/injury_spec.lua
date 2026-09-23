-- Tests for models/injury.lua -- the meter that took over from killing people.
--
-- A descent briefly lost a body outright when its downed count ran out. It does not any more: the only
-- thing that ever costs a body is a WIPE, and even then they lie where they fell to be fetched. What
-- carries the stake instead is the injury.
--
-- WHAT THIS FILE PINS CHANGED SHAPE ON 2026-09-22. An injury used to be a COUNT -- every fall took the
-- same 15% off the health pool, a damage debuff arrived at two and a movement cut at three. It is one of
-- SEVEN NAMED KINDS now, dealt by a seeded roll, each with its own reserve and its own uncleansable
-- badge, and they stack. So the cases below are about four things that did not exist before: the
-- catalogue, the roll, the stacking floor, and which bone comes off when one does.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Player = require("models.player")
local Injury = require("models.injury")
local Status = require("models.status")

local function company(n)
    local ids = { "character_knight", "character_archer", "character_rogue", "character_mage" }
    local chars = {}
    for i = 1, (n or 1) do chars[i] = Character.instantiate(ids[i]) end
    return Descent.newProfile(chars)
end

-- Deal a body a NAMED injury, n times. Most cases here are about what a kind costs rather than about
-- what the roll picks, and a rolled kind would make them read as a coin flip.
local function give(p, char, kind, n)
    for _ = 1, (n or 1) do Injury.inflict(p, { char }, kind) end
end

return {
    { name = "an injury reserves part of the body, in the fight as well as out of it", fn = function()
        -- THE HALF THAT WAS NEW IN 2026-09. It used to cap only the hub's REFILL, so an injured body
        -- started short and could then be healed straight back to full by anything on the board -- which
        -- said the injury was real and immediately showed it was not. It is a reservation: the pool is
        -- the size it always was and part of it cannot be reached, by a potion or by anything else.
        local p = company(1)
        local char = p.roster[1]
        local whole = Combat.unreservedMax(char, "health")

        give(p, char, "injury_blood_loss")
        local hurt = Combat.unreservedMax(char, "health")
        assert(hurt < whole, "one injury takes the ceiling down: " .. hurt .. " vs " .. whole)

        give(p, char, "injury_blood_loss")
        assert(Combat.unreservedMax(char, "health") < hurt, "and two take it further")

        -- `max` itself is NEVER touched. That is the whole reason this is a reservation rather than a
        -- penalty on the ceiling: max health is derived from level, growth and gear, so an injury
        -- written into it would have to be un-written exactly on the way out and would fight every
        -- recomputation in between.
        assert(char.stats.health.max == p.roster[1].stats.health.max, "the pool is the size it was")
    end },

    { name = "the reserve stops at a floor, so a body is never unfieldable", fn = function()
        -- An injury deep enough to make somebody not worth fielding takes a quarter of the company off
        -- the board as surely as killing them would, which is the exact thing this meter exists instead
        -- of. The bench absorbs a benched body; nothing absorbs a fielded one that cannot fight.
        local p = company(1)
        local char = p.roster[1]
        give(p, char, "injury_blood_loss", 12)
        assert(Injury.healShare(p, char.id) == Injury.FLOOR, "twelve injuries bottom out at the floor")
        assert(Combat.unreservedMax(char, "health") >= math.floor(char.stats.health.max * Injury.FLOOR) - 1,
            "and the body keeps at least the floor's share of itself")
    end },

    { name = "a pool nothing reserves is untouched, and one that is reserved answers alone", fn = function()
        -- IT USED TO BE HEALTH-ONLY, by a condition in Combat.unreservedMax rather than by anything the
        -- meter said. Two of the seven kinds are about the other pools by construction, so the share is
        -- asked for BY STAT -- and an injury that says nothing about a pool must still say nothing.
        local p = company(1)
        local char = p.roster[1]
        local mana = Combat.unreservedMax(char, "mana")
        local stamina = Combat.unreservedMax(char, "stamina")

        give(p, char, "injury_blood_loss")
        assert(Combat.unreservedMax(char, "mana") == mana, "Blood Loss does not seal mana")
        assert(Combat.unreservedMax(char, "stamina") == stamina, "nor stamina")

        give(p, char, "injury_ruptured_font")
        assert(Combat.unreservedMax(char, "mana") < mana, "a Ruptured Font does")
        assert(Combat.unreservedMax(char, "stamina") == stamina, "...and still leaves the stamina alone")
    end },

    { name = "every kind in the catalogue is whole, and the weights are a distribution", fn = function()
        -- The blueprint contract, asserted over the folder rather than over a list typed twice: an
        -- eighth injury is a file, and a file missing a field is a crash at the bell or a row the Ward
        -- cannot name.
        local n = 0
        for _, id in ipairs(Injury.order()) do
            local def = Injury.defs[id]
            n = n + 1
            assert(def.name and def.name ~= "", id .. " has no name")
            assert(def.description and def.description ~= "", id .. " has no description")
            assert(type(def.severity) == "number", id .. " has no severity -- Injury.sorted cannot place it")
            assert((def.weight or 0) > 0, id .. " can never be rolled")
            local takes = false
            for _, share in pairs(def.reserve or {}) do
                assert(share > 0 and share < 1, id .. " reserves a nonsense share")
                takes = true
            end
            for _, effect in ipairs(def.effects or {}) do
                assert(Status.defs[effect.id], id .. " names " .. tostring(effect.id) .. ", which is not a status")
                takes = true
            end
            -- A KIND THAT TAKES NOTHING IS A ROLL THAT COST NOTHING, which reads as a bug rather than as
            -- luck. The review denied a `fits` gate, so this is the rule that stands in its place: every
            -- kind bites every body, because every kind reserves health as well as whatever else it does.
            assert(takes, id .. " costs the body nothing at all")
            assert((def.reserve or {}).health, id .. " takes no health, so it is free on some bodies")
        end
        assert(n == 7, "seven kinds ship; found " .. n)
    end },

    { name = "no injury badge can be lifted by a Cure, which is the bug this set was built over", fn = function()
        -- THE LIVE DEFECT THE NAMED KINDS FIXED. The count-based meter stamped `status_cripple` at three
        -- wounds -- and Cripple is `debuff = true`, so Status.cleanse stripped it. One Cure lifted the
        -- campaign's whole attrition meter for the rest of the fight, and neither the ability nor the
        -- meter knew it was happening.
        --
        -- Asserted over the CATALOGUE rather than over the one id that used to be wrong, because the
        -- next author to reach for a convenient existing badge will reach for a cleansable one.
        for _, id in ipairs(Injury.order()) do
            for _, effect in ipairs(Injury.defs[id].effects or {}) do
                local def = Status.defs[effect.id]
                assert(not def.debuff, effect.id .. " is cleansable -- a Cure would lift " .. id)
                assert((def.duration or 0) > 500, effect.id .. " would tick away inside a fight")
            end
        end
    end },

    { name = "the roll is dealt from the seed, so the same save deals the same bone", fn = function()
        -- THE SAME RULE THE FLOORS KEEP: a floor's ground comes from the seed and the depth alone, so
        -- floor three is the same floor three for the life of a playthrough. An injury is the other
        -- thing a trip hands you. A live roll would make save-scumming the optimal way to play a meter
        -- whose entire job is to make you live with what happened.
        local a, b = company(2), company(2)
        a.seed, b.seed = 424242, 424242
        a.descentRun = { floor = 3 }
        b.descentRun = { floor = 3 }

        Injury.inflict(a, { a.roster[1] })
        Injury.inflict(b, { b.roster[1] })
        assert(Injury.list(a, a.roster[1].id)[1] == Injury.list(b, b.roster[1].id)[1],
            "two saves on one seed deal the same injury on the same floor")

        -- ...AND IT IS NOT ONE FIXED ANSWER. A hash that ignored its inputs would pass the case above
        -- and deal Blood Loss to everybody forever, which is the failure that looks most like success.
        local seen = {}
        for floor = 1, 15 do
            local p = company(2)
            p.seed, p.descentRun = 424242, { floor = floor }
            for i = 1, 8 do
                Injury.inflict(p, { p.roster[1] })
                seen[Injury.list(p, p.roster[1].id)[i]] = true
            end
        end
        local kinds = 0
        for _ in pairs(seen) do kinds = kinds + 1 end
        assert(kinds >= 4, "a hundred and twenty rolls dealt only " .. kinds .. " kinds")
    end },

    { name = "a named kind bypasses the roll, which is what the tutorial is built on", fn = function()
        -- The prologue's scripted casualty must take Blood Loss and nothing else: the coach bubble on
        -- the far side of that fight points at the dark band on her bar, and a rolled Shattered Leg
        -- draws no band -- so the one teaching moment the mechanic gets would be an arrow pointing at
        -- nothing (states/game.lua's objective branch, states/prologue.lua's skip).
        local p = company(1)
        local char = p.roster[1]
        for _ = 1, 6 do Injury.inflict(p, { char }, "injury_blood_loss") end
        for _, id in ipairs(Injury.list(p, char.id)) do
            assert(id == "injury_blood_loss", "a named kind was rolled over: got " .. id)
        end
    end },

    { name = "injuries stack, and every stat they move has a floor", fn = function()
        -- STACKING WAS THE REVIEW'S CALL and it is what makes the floor load-bearing. The reserve has
        -- always had one; the stat cuts did not, so six bad trips would have read -12 movement and a
        -- body that cannot leave its tile.
        local p = company(1)
        local char = p.roster[1]
        local base = char.stats.movement

        give(p, char, "injury_shattered_leg")
        local one = Injury.combatEffects(p, char.id, char)
        assert(#one == 1 and one[1].id == "status_shattered_leg", "one leg, one badge")
        assert(one[1].opts.statBonus.movement == -2, "at the authored figure")

        give(p, char, "injury_shattered_leg", 8)
        local many = Injury.combatEffects(p, char.id, char)
        -- ONE BADGE, NOT NINE. Status.apply refreshes rather than stacking instances, so nine effects
        -- handed over would land as one -2 and the ledger would be lying.
        assert(#many == 1, "a kind carried nine times is still one badge, got " .. #many)
        local cut = -many[1].opts.statBonus.movement
        assert(cut < 9 * 2, "the cut is clamped, not summed raw")
        assert(base - cut >= math.max(1, math.floor(base * Injury.STAT_FLOOR)),
            "a body with nine broken legs is still above the floor: " .. (base - cut) .. " of " .. base)
    end },

    { name = "two kinds moving two stats each are clamped independently", fn = function()
        -- The clamp is per STAT, not per badge. Rattled moves skill and speed; Cracked Ribs moves
        -- defense. Spending one allowance must not eat another's.
        local p = company(1)
        local char = p.roster[1]
        give(p, char, "injury_rattled")
        give(p, char, "injury_cracked_ribs")
        local effects = Injury.combatEffects(p, char.id, char)
        assert(#effects == 2, "two kinds, two badges")
        local byId = {}
        for _, e in ipairs(effects) do byId[e.id] = e end
        assert(byId["status_rattled"].opts.statBonus.skill < 0, "the head still bites")
        assert(byId["status_cracked_ribs"].opts.statBonus.defense < 0, "and so do the ribs")
    end },

    { name = "a body with no char handed in gets the authored figures, unfloored", fn = function()
        -- The clamp is measured against a body's own base, so a caller holding an id and no instance
        -- cannot compute it. That caller gets what the blueprint says rather than a silent zero -- and
        -- the battle always passes the char (states/game.lua's resolveOpening).
        local p = company(1)
        local char = p.roster[1]
        give(p, char, "injury_shattered_leg", 4)
        local bare = Injury.combatEffects(p, char.id)
        assert(bare[1].opts.statBonus.movement == -8, "unfloored, the four legs sum raw")
    end },

    { name = "a field dressing sets the SHALLOWEST bone, in both rooms that set one", fn = function()
        -- THE RULE THAT STANDS IN FOR A PICKER. Neither the camp's bind nor the Ward's press asks which
        -- injury comes off -- the review denied naming them on the desk -- so the answer is stated once
        -- and kept in both places, or the player learns it twice and differently.
        local p = company(1)
        local char = p.roster[1]
        give(p, char, "injury_blood_loss")   -- severity 3
        give(p, char, "injury_cracked_ribs") -- severity 2
        give(p, char, "injury_rattled")      -- severity 1

        Injury.mend(p, 1)
        local left = Injury.list(p, char.id)
        assert(#left == 2, "one bone came off")
        for _, id in ipairs(left) do
            assert(id ~= "injury_rattled", "the camp set the shallowest -- Rattled should be gone")
        end

        -- ...and the Ward's gold press keeps the same rule.
        p.gold = Injury.TREAT_COST
        assert(Injury.treat(p, char.id), "the purse covers one")
        for _, id in ipairs(Injury.list(p, char.id)) do
            assert(id == "injury_blood_loss", "the deepest is what a company is left holding")
        end
    end },

    { name = "setting the bone gives the body back, reserve and badges alike", fn = function()
        local p = company(1)
        local char = p.roster[1]
        local whole = Combat.unreservedMax(char, "health")
        give(p, char, "injury_blood_loss")
        give(p, char, "injury_shattered_leg")
        give(p, char, "injury_torn_shoulder")
        assert(#Injury.combatEffects(p, char.id, char) == 2, "precondition: three injuries, two badges")

        -- Three camps spent on Bind rather than on the heal, the whetstone or the map -- which is the
        -- only way to shed one without reaching the Ward (models/injury.lua's Injury.mend).
        for _ = 1, 3 do Injury.mend(p, 1) end

        assert(Injury.count(p, char.id) == 0, "the injuries are gone")
        assert(#Injury.combatEffects(p, char.id, char) == 0, "and so are the badges")
        assert(Combat.unreservedMax(char, "health") == whole, "and the body is its whole size again")
    end },

    { name = "binding a camp sets one bone on everybody, and never more than one", fn = function()
        -- THE ONLY BONE-SETTING THE FLOORS HAVE, and it is a decision rather than a service: the camp
        -- that binds is a camp that did not heal, sharpen or study (states/game.lua's restBind). One
        -- rung at a time, so a company three fights into a bad dive cannot buy the whole ladder back at
        -- one stop.
        local p = company(2)
        for _ = 1, 3 do
            Injury.inflict(p, { p.roster[1], p.roster[2] }, "injury_blood_loss")
        end

        local mended = Injury.mend(p, 1)
        assert(#mended == 2, "both bodies were carrying something, so both were set")
        for _, char in ipairs(p.roster) do
            assert(Injury.count(p, char.id) == 2, (char.id) .. " should be down to two, not clear")
            assert(Combat.unreservedMax(char, "health") < char.stats.health.max,
                (char.id) .. " is not still reserved -- the injury stopped biting")
        end

        -- ...AND IT PAYS NOTHING TO A COMPANY THAT IS WHOLE, which is what the control reads before it
        -- draws at all: no injury, no row.
        Injury.mend(p, 9)
        assert(#Injury.mend(p, 1) == 0, "a whole company has nothing to bind")
    end },

    { name = "the ward sets a bone for gold, one injury per payment", fn = function()
        -- STANDING ABOVE GROUND USED TO BE THE WHOLE OF IT: Injury.clear ran on both town screens and an
        -- expedition's damage ended free the moment anybody was in the city. It is a door now, because
        -- an injury that evaporates on arrival cannot be taught, cannot be decided about, and gave the
        -- room the tutorial points at nothing to do.
        local p = company(2)
        local char = p.roster[1]
        give(p, char, "injury_blood_loss", 2)
        p.gold = Injury.TREAT_COST

        assert(Injury.treat(p, char.id), "the purse covers one")
        assert(Injury.count(p, char.id) == 1, "and it buys exactly one injury off, not the body clean")
        assert(p.gold == 0, "the gold is spent")
        assert(not Injury.treat(p, char.id), "a short purse buys nothing, and says so rather than half-paying")
        assert(Injury.count(p, char.id) == 1, "...and takes nothing when it refuses")
    end },

    { name = "the price does not move with the kind, which is the count's own law", fn = function()
        -- docs/the-count.md: a cost on recovery is a tax on NEEDING to recover. Charging more for a
        -- Shattered Leg than for Blood Loss would tax the worse luck, and the worse luck already cost
        -- the player the injury. Gold buys SPEED, never recovery.
        for _, kind in ipairs({ "injury_blood_loss", "injury_shattered_leg", "injury_ruptured_font" }) do
            local p = company(1)
            local char = p.roster[1]
            give(p, char, kind)
            p.gold = Injury.TREAT_COST
            assert(Injury.treat(p, char.id), kind .. " costs more than the flat fee")
            assert(p.gold == 0, kind .. " left change, so the fee is not flat")
            assert(Injury.rest(p, char.id) == 0, kind .. " still had something to rest off")
        end
    end },

    { name = "resting is free, costs descents, and mends on the term it was bought for", fn = function()
        -- THE FREE PATH IS THE WHOLE LEGALITY OF THE ROOM. Two earlier versions of this building were
        -- deleted for charging at the door (models/injury.lua's ward block), and what makes this one
        -- legal is that the gold buys SPEED and never recovery -- so a company with nothing can always
        -- mend, and pays only in who walks down without them.
        local p = company(2)
        local char = p.roster[1]
        p.gold = 0
        give(p, char, "injury_blood_loss")

        local owed = Injury.rest(p, char.id)
        assert(owed == Injury.REST_DESCENTS, "one injury lies up for one term")
        assert(p.gold == 0, "and it took nothing -- there is no purse test on the free path")
        assert(Injury.resting(p, char.id) == owed, "she is in the ward")
        assert(Injury.count(p, char.id) == 1, "...and still hurt until the term is served")

        -- A DAY IS A DESCENT. Nothing else in this game passes time, which is why the term is priced in
        -- trips rather than in calendar days (models/gate.lua's Gate.night is the only tick).
        for i = 1, owed - 1 do
            Injury.tickRest(p)
            assert(Injury.resting(p, char.id) > 0, "still lying up after " .. i .. " descent(s)")
            assert(Injury.count(p, char.id) == 1, "and still hurt")
        end
        local up = Injury.tickRest(p)
        assert(#up == 1 and up[1] == char.id, "the last descent walks her out, and the tick names her")
        assert(Injury.resting(p, char.id) == 0, "out of the ward")
        assert(Injury.count(p, char.id) == 0, "and whole")
        assert(char.injuryShare == nil, "with no reserve left stamped on the body")
    end },

    { name = "a longer stay is never shortened by being sent back to bed", fn = function()
        -- Injury.rest multiplies by the injury count, so a body carried out three times owes three terms.
        -- Pressing rest again on a body already lying up must not reset it to the shorter stay -- that
        -- would make the free path cheaper the more often you pressed it.
        local p = company(1)
        local char = p.roster[1]
        give(p, char, "injury_blood_loss", 3)
        local long = Injury.rest(p, char.id)
        assert(long == 3 * Injury.REST_DESCENTS, "three injuries, three terms")

        Injury.treat(p, char.id) -- (no gold: refused, the count is untouched)
        assert(Injury.rest(p, char.id) == long, "resting again holds the longer term rather than re-pricing it")
    end },

    { name = "a body in the ward cannot be sent down, which is what resting actually costs", fn = function()
        -- THE FILTER IS THE PRICE. Resting takes no gold and no purse test, so the only thing it costs
        -- is the body: out of the company for the descents its term runs, against an expedition of four.
        -- Without this the free path costs nothing at all and nobody would ever pay Injury.TREAT_COST.
        local p = company(2)
        local hurt, spare = p.roster[1], p.roster[2]
        give(p, hurt, "injury_blood_loss")

        local run = Descent.new(p, 1)
        local before = Descent.party(run, p)
        assert(#before == 2, "both bodies are pickable while nobody is lying up")

        Injury.rest(p, hurt.id)
        local after = Descent.party(run, p)
        assert(#after == 1 and after[1].id == spare.id,
            "the resting body is strained out of the company, not merely greyed in a picker")

        -- ...and a party PICKED before the stay began does not smuggle her down either.
        Descent.setParty(run, { hurt.id, spare.id })
        local picked = Descent.party(run, p)
        for _, char in ipairs(picked) do
            assert(char.id ~= hurt.id, "a stale pick cannot field somebody who is in the ward")
        end

        -- She comes back when the term is served, and is pickable again on the same call.
        for _ = 1, Injury.REST_DESCENTS do Injury.tickRest(p) end
        local back = Descent.party(run, p)
        assert(#back == 2, "out of the ward is back in the company")
    end },

    { name = "the reserve is stamped onto bodies, never read off the player by combat", fn = function()
        -- Injuries are keyed by char id on the PLAYER; Combat.unreservedMax takes a CHARACTER and no
        -- player, which is right -- it is asked about summons, enemies and duel rosters that have no
        -- player behind them at all. So the share arrives on the character the way `maxBonus` does.
        local p = company(1)
        local char = p.roster[1]
        give(p, char, "injury_blood_loss")
        assert(type(char.injuryShare) == "table", "the share is written onto the body")
        assert((char.injuryShare.health or 0) > 0, "and it says which pool")

        -- An unhurt body carries no field at all, so the fast path is a single nil test.
        local clean = company(1)
        assert(clean.roster[1].injuryShare == nil, "an unhurt body carries no share")

        -- And a body with no player behind it is untouched by any of this.
        local loose = Character.instantiate("character_bandit")
        assert(Combat.unreservedMax(loose, "health") == loose.stats.health.max,
            "a body with no player is not injured by association")
    end },

    { name = "every body that can be fielded declares every stat an injury moves", fn = function()
        -- THE CLAMP CAN HIDE AN AUTHORING ERROR, and this is the guard. An injury's cut is measured
        -- against the body's own base (Injury.STAT_FLOOR); a body that declares no such stat gets an
        -- allowance of zero, so the badge lands at -0 and the injury silently does nothing to it.
        --
        -- That is the right arithmetic -- you cannot take a quarter off a stat that is not there -- and
        -- the wrong outcome, because the whole reason the review denied a `fits` gate is that no roll
        -- may ever cost a body nothing. So the rule is enforced at the other end: anything the player
        -- can put in a company declares every stat the seven kinds move.
        --
        -- Monsters are exempt and stay exempt: 33 of the 153 blueprints carry no `staminaRegen`, they
        -- are never on a roster, and nothing keyed by character id on the PLAYER can ever reach them.
        -- A PORTRAIT IS NOT THE FILTER -- the generals have portraits and are bodies you fight. The set
        -- is named where the game names it: every class's `exemplar` is that house's companion (the
        -- seven roots are the companions themselves), which is what a roster is actually built out of,
        -- plus the generic templates a hire is rolled from.
        local Character = require("models.character")
        local Class = require("models.class")
        local stats = {}
        for _, id in ipairs(Injury.order()) do
            for _, effect in ipairs(Injury.defs[id].effects or {}) do
                for stat in pairs(Status.defs[effect.id].statBonus or {}) do stats[stat] = true end
            end
        end
        local fieldable = {}
        for _, def in pairs(Class.defs) do
            if def.exemplar then fieldable[def.exemplar] = true end
        end
        for _, id in ipairs({ "character_knight", "character_archer", "character_rogue", "character_mage",
            "character_priest", "character_fighter", "character_alchemist" }) do
            fieldable[id] = true
        end
        local walked = 0
        for charId in pairs(fieldable) do
            local def = Character.defs[charId]
            if def then
                walked = walked + 1
                for stat in pairs(stats) do
                    assert(type((def.stats or {})[stat]) == "number",
                        charId .. " declares no " .. stat .. ", so an injury that moves it would be free on them")
                end
            end
        end
        assert(walked >= 7, "only " .. walked .. " fieldable bodies were walked -- the set has stopped resolving")

        -- ONE GAP IS LEFT OPEN ON PURPOSE, and it is a blueprint question rather than an injury one:
        -- `character_champion` is authored `defense = 0` (a riposte-wall exemplar with 96 health and no
        -- armor at all), so Cracked Ribs has nothing to take off it and lands inert. Asserting `> 0`
        -- here would redden the suite over a balance decision this file has no business making -- so it
        -- is written down instead. If that 0 is a typo, fixing it closes this on its own.
    end },

    { name = "the two one-time marks answer different questions", fn = function()
        -- TWO LESSONS, TWO LEDGERS. `injured` arms the bubble that teaches the dark band; `injuredBadge`
        -- arms the one that teaches a badge the strip cannot draw. One flag read twice would spend the
        -- second lesson on the first injury -- which is Blood Loss by script, and has no badge.
        local p = company(1)
        local char = p.roster[1]
        assert(not Injury.everInjured(p), "a fresh company has never been hurt")
        assert(not Injury.everBadged(p), "...nor ever seen a badge")

        give(p, char, "injury_blood_loss")
        assert(Injury.everInjured(p), "the band arms the first lesson")
        assert(not Injury.everBadged(p), "and Blood Loss carries no badge, so the second is still owed")

        give(p, char, "injury_rattled")
        assert(Injury.everBadged(p), "the first badge arms the second lesson")

        -- ONE-WAY, both of them: setting every bone does not un-teach either lesson.
        Injury.mend(p, 9)
        assert(Injury.count(p, char.id) == 0, "precondition: whole again")
        assert(Injury.everInjured(p) and Injury.everBadged(p), "the marks outlive the ledger")
    end },
}
