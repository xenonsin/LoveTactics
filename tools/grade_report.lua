-- Grade ledger: what every item is worth, and where the shelf disagrees with it.
--
--   & "E:\LOVE\lovec.exe" . grade-report                per-house shelves, ranked by grade
--   & "E:\LOVE\lovec.exe" . grade-report full           ...plus the quest-reward shelf and the
--                                                       traits still riding an estimated weight
--   & "E:\LOVE\lovec.exe" . grade-report explain ID     one item's whole arithmetic, row by row
--   & "E:\LOVE\lovec.exe" . grade-report diff           proposed slot vs the slot it has today
--
-- The instrument behind models/grade.lua. It only REPORTS -- nothing here writes a blueprint. The
-- rewrite is a separate pass on purpose: the ranking has to be argued with before 650 files move,
-- which is exactly the checkpoint the last shelf pass (tools/unlock_rescale.lua) did not have.
--
-- THE PROPOSED SLOT is where the grade says an item belongs: its rank within its own house, mapped onto
-- that house's rungs -- six to eight of them, one per job the house asks for (maxGateFor, off
-- models/errand.lua's ladder). Spread by RANK rather than by grade value, deliberately -- an even spread
-- guarantees every errand opens stock, which is a real progression requirement, and the bug was never
-- the spread. It was the key.

local Grade = require("models.grade")
local Item = require("models.item")
local Vendor = require("models.vendor")
local Quest = require("models.quest")
local Trait = require("models.trait")
local Errand = require("models.errand") -- TIERS: the rung count the shelf and the errand ladder share

local M = {}

local function maxGateFor(vendorId)
    return math.max(0, Errand.tiers(vendorId) - 1)
end

-- The earliest slot a DISCIPLINE item may name. No subclass opens on a house's opener -- that job is the
-- door itself -- so nothing at slot 0 could ever be buyable. It was 3 of 12 when the band was twelve
-- rungs long; the gates now sit on tiers 1..5 (data/disciplines/*.lua), and this is the first of them.
local DISCIPLINE_FLOOR = 1

-- class -> vendor id, and how many quests each house sponsors.
local function houses()
    local vendorOf, counts = {}, {}
    for id, def in pairs(Vendor.defs) do
        if def.class then vendorOf[def.class] = id end
    end
    for _, def in pairs(Quest.defs) do
        if def.sponsor then counts[def.sponsor] = (counts[def.sponsor] or 0) + 1 end
    end
    return vendorOf, counts
end

-- The slot rank `i` of `n` lands on, over a band of 0..maxGate.
local function slotFor(i, n, maxGate)
    if n <= 1 or maxGate <= 0 then return 0 end
    return math.min(maxGate, math.floor((i - 1) * (maxGate + 1) / n))
end

local function classList()
    local seen, out = {}, {}
    for _, def in pairs(Item.defs) do
        if def.class and not seen[def.class] then
            seen[def.class] = true
            out[#out + 1] = def.class
        end
    end
    table.sort(out)
    return out
end

-- One item's arithmetic, spelled out.
local function explain(id)
    local def = Item.defs[id]
    if not def then
        print("no such item: " .. tostring(id))
        return
    end
    local value, b = Grade.of(id)
    print(string.format("\n%s  (%s, %s)", def.name or id, def.type, def.class or "classless"))
    print(string.format("  shelf today: slot %s, %s gold",
        tostring(def.unlockQuests or "-"), tostring(def.price or "-")))
    print(string.format("  one turn is worth %.1f damage (Grade.PRESTIGE %d)",
        Grade.turnValue(), Grade.PRESTIGE))
    print("  ---")
    for _, row in ipairs(b.rows) do
        print(string.format("  %-34s %+8.1f", row[1], row[2]))
    end
    print("  ---")
    print(string.format("  %-34s %8.1f   (active %.1f, passive %.1f)%s",
        "GRADE", value, b.active, b.passive,
        b.estimated and "   [leans on an estimated trait weight]" or ""))
end

-- ---------------------------------------------------------------------------
-- The rewrite
-- ---------------------------------------------------------------------------

local function sourcePath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

local function readFile(rel)
    local f = io.open(sourcePath(rel), "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

-- Never write a blueprint that would not parse. The rewriter edits source TEXT, so this is the one
-- guard between a bad pattern and a broken data file. Lifted from tools/unlock_rescale.lua, which
-- learned it the same way.
local function writeFile(rel, text)
    local ok, err = loadstring(text)
    assert(ok, "refusing to write invalid Lua to " .. rel .. ": " .. tostring(err))
    local f = assert(io.open(sourcePath(rel), "wb"))
    f:write(text)
    f:close()
end

-- Set `field = value` in a blueprint, whether or not the field is already there. An item that never
-- authored `unlockQuests` is a real case -- the field defaults to 0 -- so a rewriter that could only
-- replace an existing literal would silently skip every item that needed the change most.
-- Returns the new text, or nil if there was nowhere sensible to put it.
local function setField(text, field, value)
    local replaced, n = text:gsub("(" .. field .. "%s*=%s*)%-?%d+", "%1" .. value, 1)
    if n == 1 then return replaced end
    -- Not present: insert after `type = "..."`, which every item blueprint declares.
    local out, m = text:gsub("(\n(%s*)type%s*=%s*\"[^\"]*\",)",
        "%1\n%2" .. field .. " = " .. value .. ",", 1)
    if m == 1 then return out end
    return nil
end

-- Base weapons that must stay on the opening shelf whatever they grade.
--
-- tests/class_spec.lua requires every house to sell a weapon at gate 0 -- "a class you cannot buy a
-- weapon from before running a single quest is a class you cannot start playing" -- and the grade,
-- left alone, moves several of them off it. That is not the grader being wrong: since the last
-- balance pass every weapon on a slot shares a magnitude, so a family's base weapon is separated from
-- its neighbours only by its family CONTRACT, and a hammer's contract is a stun. The iron hammer
-- genuinely is worth more than the iron greatsword. It still has to be the thing a newcomer can buy.
--
-- So the pin is a floor on the ladder rather than a correction to the grade, the same shape
-- tools/unlock_rescale.lua's gate-0 weapon pin had. Read off Balance.FAMILY_BASE so it names the same
-- twelve weapons the magnitude ladder anchors on, and cannot drift from them.
-- ...AND THE ANCHORS THE LADDER ITSELF IS MEASURED FROM. Balance.slotAnchors reads each family's two
-- ends off its BASE weapon's own forge curve, and the ability group's off Balance.ABILITY_BASE. Those
-- twelve weapons and that one spell are the ruler. Move one and every target on its ladder moves with
-- it -- which is exactly what happened the first time this ran: the grade sent ability_fire_bolt to
-- slot 8, the anchor went with it, and every ability in the game was retargeted off the raised base.
-- A slot-0 Jolt came out hitting for sixty, and the prologue's closing beat broke.
--
-- "A ladder has to be anchored to something that does not move when the rungs do" is Balance's own
-- sentence about this, written after the same mistake in the other direction. The anchors are pinned
-- for that reason before any argument about what they are worth.
local function anchorItems()
    local Balance = require("models.balance")
    local pinned = {}
    for _, id in pairs(Balance.FAMILY_BASE) do pinned[id] = true end
    pinned[Balance.ABILITY_BASE] = true
    return pinned
end

-- The whole assignment for one house: rows ranked weakest-first with a `want` slot on each, the ones
-- the dry run cannot see set aside, and the band they were spread over.
--
-- THE single owner of the ranking, read by both the report and the rewrite. Two copies of this is
-- exactly how a tool ends up writing something its own dry run never showed.
local function planFor(class, maxGate, pinned)
    -- A BLIND ROW WITH AN `at` PIN IS NO LONGER BLIND. Being blind means the dry run could not see the
    -- item, so the grade describes the instrument and there is nothing to rank on -- but a pin is a
    -- human saying where it goes, which is the missing information supplied by hand. Those rejoin the
    -- written set so the decision actually lands in the blueprint; the rest stay set aside, keeping
    -- whatever slot they already had.
    local rows, blind = {}, {}
    for _, row in ipairs(Grade.rank(class, { priced = true })) do
        local pin = Grade.SLOT_PINS[row.id]
        if row.breakdown.blind and not (pin and pin.at) then
            blind[#blind + 1] = row
        else
            rows[#rows + 1] = row
        end
    end

    -- Ascending, so slot 0 is the bottom of the ladder.
    local asc = {}
    for i = #rows, 1, -1 do asc[#asc + 1] = rows[i] end

    -- PASS TWO: score each proposed placement against what the NEXT quest fields, and re-rank once on
    -- the adjusted value. Once, not to a fixed point -- the proposal has to come from slot-free power
    -- or the ranking is feeding its own input (see Grade.fitness).
    for i, row in ipairs(asc) do
        local proposed = slotFor(i, #asc, maxGate)
        local ratio, notes = Grade.fitness(row.id, class, proposed)
        row.fitness, row.fitNotes = ratio, notes
        row.adjusted = row.value * (ratio or 1)
    end
    table.sort(asc, function(a, b)
        if a.adjusted ~= b.adjusted then return a.adjusted < b.adjusted end
        return a.id < b.id
    end)

    -- ONE SPREAD, TO AN EVEN COUNT PER RUNG -- and the rung's capacity is what the pins are counted
    -- against, not something they sit on top of.
    --
    -- It used to be TWO spreads, the base shelf over the whole line and the discipline cut over
    -- everything above DISCIPLINE_FLOOR, and they were never summed. The bottom rungs therefore held
    -- base stock alone and every rung above the floor held both, which is not a curve anyone chose: the
    -- shipped shelf ran 32, 15, 16 and then 66 across its first four rungs. An errand that opens two
    -- wares is a job run for a tooltip.
    --
    -- The old comment here defended the split, and the thing it was defending against is real: clamping
    -- discipline rows UP to the floor piles every low-grading one onto that single slot and starves the
    -- rungs under it. This does not clamp. A discipline row that comes up while the walk is still below
    -- the floor is HELD, a base row takes its place, and it is dealt in at the first legal rung -- so
    -- the floor costs it its position in the ranking and nothing else.
    --
    -- The pins are taken OUT before the walk, as they always were: moving them afterwards leaves a hole
    -- exactly where each one used to sit. What is new is that their rung's capacity is reduced by what
    -- they took, so sixteen ladder anchors pinned to slot 0 no longer arrive on top of a full rung's
    -- worth of graded stock.
    local spread, taken = {}, {}
    for _, row in ipairs(asc) do
        local pin = Grade.SLOT_PINS[row.id]
        if pinned[row.id] or (pin and pin.at) then
            row.want = pinned[row.id] and 0 or pin.at
            row.pinned = pinned[row.id] and "ladder anchor" or pin.why
            taken[row.want] = (taken[row.want] or 0) + 1
        else
            spread[#spread + 1] = row
        end
    end

    -- The share is of the WHOLE shelf, pins included, and each rung's room is its share less what was
    -- pinned into it. Sizing the share off the un-pinned rows alone leaves every rung short by its own
    -- pins and the slack falls through to the last one -- which came out at 124 wares against 70.
    local rungs, n = maxGate + 1, #spread
    for _, count in pairs(taken) do n = n + count end
    local room, slot = {}, 0
    for s = 0, maxGate do
        room[s] = math.max(0, math.floor(n / rungs) + ((s < n % rungs) and 1 or 0) - (taken[s] or 0))
    end
    local floor = math.min(DISCIPLINE_FLOOR, maxGate)

    -- TWO QUEUES IN RANK ORDER, and each rung takes its plain rows first.
    --
    -- A rung whose whole intake is discipline stock is a rung that opens NOTHING for a player who has
    -- not unlocked that discipline: they run the job, walk into the shop, and the shelf has not moved.
    -- tests/balance_spec.lua reads exactly that and it is the reason the two bands were spread apart in
    -- the first place. Splitting them is not the only way to get it, though, and the old way bought it at
    -- the price of the curve: a floor of PLAIN_FLOOR plain rows per rung, filled from the ranked list
    -- before anything else, buys the same guarantee while the rest of the rung still fills by grade.
    --
    -- Affordable by construction: a house carries 26 to 43 plain wares over six to eight rungs.
    local PLAIN_FLOOR = 2
    local baseQ, deepQ, bi, di = {}, {}, 1, 1
    for _, row in ipairs(spread) do
        if row.def.discipline then deepQ[#deepQ + 1] = row else baseQ[#baseQ + 1] = row end
    end
    for s = 0, maxGate do
        local placed = 0
        while placed < room[s] and placed < PLAIN_FLOOR and baseQ[bi] do
            baseQ[bi].want = s; bi = bi + 1; placed = placed + 1
        end
        while placed < room[s] do
            local b = baseQ[bi]
            local d = s >= floor and deepQ[di] or nil -- nothing deep sits under the discipline floor
            local pick
            if b and d then pick = (b.adjusted <= d.adjusted) and b or d
            else pick = b or d end
            if not pick then break end
            pick.want = s
            if pick == b then bi = bi + 1 else di = di + 1 end
            placed = placed + 1
        end
    end
    -- Whatever the rounding left over goes on the top rung, which is where the deepest stock belongs.
    for i = bi, #baseQ do baseQ[i].want = maxGate end
    for i = di, #deepQ do deepQ[i].want = maxGate end

    for _, row in ipairs(asc) do
        row.have = row.def.unlockQuests or 0
        row.adopted = false
        for _, tid in ipairs(row.def.traits or {}) do
            if Grade.TRAIT_ADOPTED[tid] then row.adopted = true break end
        end
    end

    -- ...then lay the pins over the spread, after it rather than inside it: the ladder above is what
    -- the grade says, and these are the places an authored contract says it does not get to decide.
    for _, row in ipairs(asc) do
        -- `at` pins were seated before the spread; only the RANGE pins are left to clamp here, and a
        -- clamp cannot leave a hole -- it moves a row within the band rather than out of it.
        local pin = Grade.SLOT_PINS[row.id]
        if pin and not pin.at then
            if pin.min and row.want < pin.min then row.want = pin.min end
            if pin.max and row.want > pin.max then row.want = pin.max end
            row.pinned = pin.why
        end
    end

    -- A HOUSE MUST ARM A NEWCOMER. tests/class_spec.lua: "a class you cannot buy a weapon from before
    -- running a single quest is a class you cannot start playing." The family-base pins cover six
    -- houses; the alchemist's weapons are all its own poisons and none is a family base, so the rule has
    -- to be asked per house rather than assumed from the base list. Cheapest-to-grade goes down, since
    -- the opening weapon should be the plainest thing on the rack.
    local hasOpener = false
    for _, row in ipairs(asc) do
        if row.def.type == "weapon" and row.want <= 0 and not row.def.discipline then hasOpener = true end
    end
    if not hasOpener then
        -- CHOSEN ON RAW GRADE, not on the adjusted order, and that is the difference between a rule and
        -- a coin flip. `asc` is sorted by the FITNESS-adjusted value, and fitness reads the proposed
        -- slot -- so picking the first weapon out of it means the choice depends on the assignment it is
        -- feeding. The Crucible has no family base, and its two plain weapons traded the opening seat
        -- every round: the pass stopped converging and sat in a 2-cycle forever. `value` is slot-free by
        -- construction, so this settles on the same weapon every time.
        local opener
        for _, row in ipairs(asc) do
            if row.def.type == "weapon" and not row.def.discipline then
                if not opener or row.value < opener.value
                    or (row.value == opener.value and row.id < opener.id) then
                    opener = row
                end
            end
        end
        if opener then opener.want, opener.pinned = 0, "this house's opening weapon" end
    end
    return asc, blind
end

function M.run(args)
    local mode = args and args[1]

    -- The trait worksheet: everything a person needs to put a number on a trait, and nothing else.
    -- Traits are the one input models/grade.lua cannot derive (they are hook functions), so all 114
    -- ride an estimate until somebody authors `grade` on the blueprint, in turns per fight.
    if mode == "traits" then
        -- THE SEEDING RULE, as the designer stated it: what does damage or takes the enemy's turn away
        -- sits high; what merely ANSWERS something sits in the middle; what only describes a state sits
        -- low. Applied here rather than in the bench so the seed is reproducible and arguable, and so a
        -- retuned trait re-seeds itself.
        --
        -- Reactive is tested FIRST and wins outright, which is the rule's whole point. A parry deals
        -- damage and a Thorns coat deals damage, but neither is a damage trait -- they are answers, and
        -- an answer only ever happens on somebody else's terms. Sorting them by what they emit would
        -- put every counter in the game at the top of a ladder they have no business on.
        local HARD_CC = {
            "status_stun", "status_freeze", "status_sleep", "status_root", "status_halted",
            "status_silenced", "status_disarmed", "status_polymorph", "status_charm",
            "status_suspended", "status_downed", "status_duelbound", "status_interred",
            "status_knell", "status_sealed",
        }
        -- The trait's CODE, with its prose stripped. Headers in this codebase are long and name other
        -- systems constantly -- trait_second_wind's explains that "Combat.dealFlatDamage consults
        -- Trait.trySurvive" -- so a scan over the whole file reads a comment about the damage core as a
        -- trait that deals damage, and seeds a revival reflex as a weapon. Body only, comments removed.
        local function codeOf(id)
            local src = love.filesystem.read("data/traits/" .. id .. ".lua") or ""
            local i = src:find("return%s*{")
            src = i and src:sub(i) or src
            return (src:gsub("%-%-%[%[.-%]%]", " "):gsub("%-%-[^\n]*", " "))
        end

        local function seedFor(id, def)
            local src = codeOf(id)

            local reactive = def.counter or def.onDamaged or def.evadesPhysical or def.countersSpell
                or def.deflectsMelee or def.preemptsAttack or def.substitutes or def.onSummonLost
                or def.followUp or def.unanswerableAfterMove or def.unanswerableVsHeld
            if reactive then return 3.0 end

            local hurts = src:find("ctx%.damage%(") or src:find("ctx%.basicAttack%(")
                or src:find("dealFlatDamage") or def.damageBonusVs ~= nil
                or def.magnitude and src:find("blast") ~= nil
            -- CC only counts when the code APPLIES it. Naming a status is not inflicting one: Unbidden
            -- sheds Charm and the Sealed Reliquary holds a ward against a Seal, and matching the bare id
            -- seeded both of those defensive reflexes as crowd control.
            local cc = def.stunsOnCollision or def.haltsOwnHazards or def.marksTrapped
            for _, s in ipairs(HARD_CC) do
                if src:find("applyStatus%([^)]*" .. s) then cc = true break end
            end
            if hurts and cc then return 6.0 end
            if hurts or cc then return 4.5 end

            -- Something happens, but it neither hurts nor holds: a heal, a summon rider, a resource.
            local acts = src:find("ctx%.heal%(") or src:find("ctx%.applyStatus%(")
                or src:find("ctx%.addBonus%(") or src:find("grantItem") or src:find("restoreResource")
                or def.hastensSummons or def.bolstersSummons or def.summonsShrugHazards
                or def.brewsEachTurn or def.revivesOnLethal or def.lendsGuard
            if acts then return 2.0 end

            -- A standing condition and nothing else. Low, per the rule -- and low is where an authored
            -- weight is most likely to disagree, which is exactly what the bench is for.
            local bare = true
            for k in pairs(def) do
                if k ~= "name" and k ~= "description" then bare = false break end
            end
            return bare and 0.5 or 1.0
        end

        local carriers = {}
        for id, def in pairs(Item.defs) do
            for _, tid in ipairs(def.traits or {}) do
                carriers[tid] = carriers[tid] or {}
                table.insert(carriers[tid], { id = id, class = def.class, type = def.type })
            end
        end

        local ids = {}
        for id in pairs(Trait.defs) do ids[#ids + 1] = id end
        table.sort(ids)

        print("id\tname\thooks\tcooldown\tmagnitude\tseed_turns\tauthored\tcarriers\tdescription")
        for _, id in ipairs(ids) do
            local def = Trait.defs[id]
            local _, authored = Grade.traitValue(id)
            local value = seedFor(id, def) * math.max(1, Grade.turnValue())
            local hooks = {}
            for k, v in pairs(def) do
                if type(v) == "function" and k:match("^on") then hooks[#hooks + 1] = k end
            end
            table.sort(hooks)
            local who = {}
            for _, c in ipairs(carriers[id] or {}) do
                who[#who + 1] = c.id .. "(" .. tostring(c.class) .. "/" .. c.type .. ")"
            end
            print(string.format("%s\t%s\t%s\t%s\t%s\t%.2f\t%s\t%s\t%s",
                id, def.name or "?", table.concat(hooks, "+"),
                tostring(def.cooldown or ""), tostring(def.magnitude or ""),
                value / math.max(1, Grade.turnValue()), tostring(authored),
                table.concat(who, " "), (def.description or ""):gsub("%s+", " ")))
        end
        return
    end

    if mode == "explain" then
        for i = 2, #args do explain(args[i]) end
        if #args < 2 then print("usage: grade-report explain <item id> [more ids]") end
        return
    end

    -- THE REWRITE. Writes `unlockQuests` and `price` into every priced blueprint from the plan above.
    -- Everything else in this file only reports; this is the one door that moves data, and it is behind
    -- an explicit word.
    --
    -- Two things it deliberately does NOT touch. The items the dry run cannot see keep the slot a human
    -- gave them -- a grade that describes the instrument is no basis for moving anything. And it does
    -- not touch MAGNITUDE: Balance.slotTarget derives that from the slot, so moving slots leaves the
    -- roster out of band by design, and `balance-rescale apply` is the pass that settles it afterwards.
    -- Doing both here would hide which of the two decided any given number.
    if mode == "apply" then
        local vendorOf, counts = houses()
        local pinned = anchorItems()
        local wrote, missed, same = 0, {}, 0

        for _, class in ipairs(classList()) do
            local vid = vendorOf[class]
            local maxGate = maxGateFor(vid)
            local asc = planFor(class, maxGate, pinned)

            for _, row in ipairs(asc) do
                local price = Grade.priceFor(row.want, row.def.type)
                if row.want == row.have and price == row.def.price then
                    same = same + 1
                else
                    local rel = "data/items/" .. tostring(row.def.type) .. "/" .. row.id .. ".lua"
                    local text = readFile(rel)
                    local out = text and setField(text, "unlockQuests", row.want)
                    out = out and setField(out, "price", price)
                    if not out then
                        missed[#missed + 1] = row.id
                    else
                        writeFile(rel, out)
                        wrote = wrote + 1
                    end
                end
            end
        end

        print(string.format("%d blueprints rewritten, %d already correct, %d could not be located.",
            wrote, same, #missed))
        for _, id in ipairs(missed) do print("  unwritable: " .. id) end
        print("\nMagnitudes are now out of band by construction -- the slot moved and Balance.slotTarget")
        print("reads it. Run `. balance-rescale apply` next, then the suite.")
        return
    end

    local vendorOf, counts = houses()
    local full = mode == "full"
    local diffOnly = mode == "diff"

    print(string.format("One turn = %.1f damage against the reference body at prestige %d.",
        Grade.turnValue(), Grade.PRESTIGE))
    print("Every grade below is that same scale: what the item adds to the turn it is on.\n")

    local moved, held, estimated, adopted = 0, 0, 0, 0
    local misfits, blind = {}, {}

    local pinned = anchorItems()

    for _, class in ipairs(classList()) do
        local vid = vendorOf[class]
        local maxGate = maxGateFor(vid)
        local asc, blindRows = planFor(class, maxGate, pinned)

        for _, row in ipairs(blindRows) do
            blind[#blind + 1] = string.format("%-10s %-40s was slot %2d  %5sg",
                class, row.id, row.def.unlockQuests or 0, tostring(row.def.price or "-"))
        end

        if #asc > 0 then
            print(string.format("=== %s (%s, %d quests -> slots 0..%d) -- %d priced items",
                class, tostring(vid), vid and counts[vid] or 0, maxGate, #asc))

            local cur
            for _, row in ipairs(asc) do
                local want, have = row.want, row.have
                if row.fitness and row.fitness < 0.7 then
                    misfits[#misfits + 1] = string.format("%-10s %-38s slot %2d -> faces %s: %s",
                        class, row.id, want, tostring(want + 1),
                        table.concat(row.fitNotes or {}, "; "))
                end
                if want ~= have then moved = moved + 1 else held = held + 1 end
                if row.breakdown.estimated then estimated = estimated + 1 end
                if row.adopted then adopted = adopted + 1 end

                if not diffOnly then
                    if want ~= cur then cur = want; print(string.format("  -- slot %d", want)) end
                    print(string.format(
                        "    %-40s %-10s grade %7.1f %-7s was slot %2d %5sg -> %4dg %s%s",
                        row.id, row.def.type, row.value,
                        row.fitness and string.format("x%.2f", row.fitness) or "",
                        have, tostring(row.def.price or "-"),
                        Grade.priceFor(want, row.def.type),
                        (want ~= have) and string.format("[%+d]", want - have) or "",
                        (row.pinned and " PIN" or "") .. (row.adopted and " ~" or "")))
                elseif math.abs(want - have) >= 3 then
                    print(string.format("  %-10s %-40s grade %7.1f   slot %2d -> %2d  [%+d]",
                        class, row.id, row.value, have, want, want - have))
                end
            end
            print("")
        end
    end

    if full then
        print("\n=== quest rewards (no price, no slot -- graded all the same)")
        local rows = {}
        for id, def in pairs(Item.defs) do
            if not def.price then
                local value = Grade.of(id)
                if value then rows[#rows + 1] = { id = id, def = def, value = value } end
            end
        end
        table.sort(rows, function(a, b) return a.value > b.value end)
        for _, row in ipairs(rows) do
            print(string.format("  %-42s %-10s %-11s grade %7.1f",
                row.id, row.def.type, row.def.class or "-", row.value))
        end

        print("\n=== statuses the grade reads as WORTH NOTHING")
        print("    (their mechanic lives somewhere models/grade.lua cannot see -- an AI redirect, a")
        print("     Combat branch keyed off the id -- so each needs an authored `grade`, in turns)")
        local Status = require("models.status")
        local sids = {}
        for id in pairs(Status.defs) do sids[#sids + 1] = id end
        table.sort(sids)
        local zero = 0
        for _, id in ipairs(sids) do
            if Grade.statusValue(id) <= 0 then
                zero = zero + 1
                local d = Status.defs[id]
                print(string.format("  %-34s %-26s dur %s", id, (d.name or "?"),
                    tostring(d.duration)))
            end
        end
        print(string.format("  (%d of %d statuses read as nothing)", zero, #sids))

        print("\n=== traits still riding an ESTIMATED weight (author `grade` in turns to pin one)")
        local ids = {}
        for id in pairs(Trait.defs) do ids[#ids + 1] = id end
        table.sort(ids)
        local n = 0
        for _, id in ipairs(ids) do
            local value, authored = Grade.traitValue(id)
            if not authored then
                n = n + 1
                print(string.format("  %-40s estimated %6.1f", id, value))
            end
        end
        print(string.format("  (%d of %d traits estimated)", n, #ids))
    end

    print("\n######## NOT RANKED: THE DRY RUN CANNOT SEE THESE ########")
    print("  (each needs board state a boardless replay has none of -- a planted charge, weapons")
    print("   beside it in the grid, a purse. Set aside, not scored: hand-place or hand-weight them.)")
    table.sort(blind)
    for _, line in ipairs(blind) do print("  " .. line) end
    print(string.format("  (%d items)", #blind))

    print("\n######## ITEMS THAT DO NOT ANSWER THE FIGHT THEY UNLOCK BEFORE ########")
    print("  (the rule: what you buy at slot N has to be worth carrying into the slot N+1 quest)")
    table.sort(misfits)
    for _, line in ipairs(misfits) do print("  " .. line) end
    if #misfits == 0 then
        print("  none -- of the slots that HAVE a quest authored to measure against.")
    end

    print(string.format("\n%d items would move slot, %d already sit where the grade puts them.",
        moved, held))
    print(string.format("%d graded values rest on a trait weight ADOPTED from the seed rather than"
        .. " weighed (marked ~).", adopted))
    if estimated > 0 then
        print(string.format("%d still ride the shape estimate -- those should be zero.", estimated))
    end
    print("\nReport only -- nothing was written. Argue with the ranking first.")
end

return M
