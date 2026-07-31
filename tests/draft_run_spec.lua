-- Tests for models/draft_run.lua: the Draft-mode run loop -- budget, the win/loss ladder, the
-- draftable pool that grows by round, and snapshot round-tripping. Pure logic, runs headless.

local DraftRun = require("models.draft_run")
local DraftChassis = require("models.draft_chassis")
local Save = require("models.save")
local Character = require("models.character")
local Item = require("models.item")

return {
    {
        name = "a fresh run opens at round 1 with the opening budget and nothing drafted",
        fn = function()
            local run = DraftRun.new(123)
            assert(run.round == 1, "starts at round 1")
            assert(run.wins == 0 and run.losses == 0, "no results yet")
            assert(run.gold == DraftRun.roundBudget(1), "granted the round-1 budget")
            assert(#run.bench == 0, "the bench is empty")
            assert(DraftRun.formationCount(run) == 0, "and the formation is empty")
            assert(DraftRun.outcome(run) == nil, "and the run is not decided")
        end,
    },
    {
        name = "ten wins takes the run; three losses ends it",
        fn = function()
            local won = DraftRun.new(1)
            for _ = 1, 9 do assert(DraftRun.recordResult(won, "win") == nil, "still playing under ten") end
            assert(DraftRun.recordResult(won, "win") == "won", "the tenth win takes it")
            assert(won.wins == 10)

            local out = DraftRun.new(1)
            assert(DraftRun.recordResult(out, "loss") == nil, "one loss is survivable")
            assert(DraftRun.recordResult(out, "loss") == nil, "two losses is survivable")
            assert(DraftRun.recordResult(out, "loss") == "eliminated", "the third ends it")
            assert(out.losses == 3)
        end,
    },
    {
        name = "a win advances the round and refreshes the budget; a decided run stops moving",
        fn = function()
            local run = DraftRun.new(1)
            run.gold = 0 -- spent it all this round
            DraftRun.recordResult(run, "win")
            assert(run.round == 2, "the round rolled over")
            assert(run.gold == DraftRun.roundBudget(2), "and the budget refreshed (unspent gold does not bank)")

            -- Push to a win and confirm a finished run refuses further results.
            local done = DraftRun.new(1)
            done.wins = 9
            assert(DraftRun.recordResult(done, "win") == "won")
            local roundAtWin = done.round
            assert(DraftRun.recordResult(done, "loss") == "won", "a decided run is untouched")
            assert(done.round == roundAtWin, "and does not advance further")
        end,
    },
    {
        name = "the draftable pool grows monotonically and only ever offers real blueprints",
        fn = function()
            local prev = 0
            for round = 1, 6 do
                local pool = DraftRun.pool(round)
                assert(#pool >= prev, "the pool never shrinks as rounds progress (round " .. round .. ")")
                for _, id in ipairs(pool) do
                    assert(Save.known(Character.defs, id), "every offered id is a real character: " .. id)
                end
                prev = #pool
            end
            assert(#DraftRun.pool(5) > #DraftRun.pool(1), "later rounds open genuinely more units")
        end,
    },
    {
        name = "gold gates a purchase: you can spend what you have and not what you don't",
        fn = function()
            local run = DraftRun.new(1)
            run.gold = 5
            assert(DraftRun.spend(run, 3) == true and run.gold == 2, "a spend you can afford goes through")
            assert(DraftRun.spend(run, 5) == false and run.gold == 2, "one you can't is refused and costs nothing")
            DraftRun.addGold(run, 4)
            assert(run.gold == 6, "selling adds gold back")
        end,
    },
    {
        name = "drafting auto-fills the formation, then spills to the bench, then refuses when both are full",
        fn = function()
            local run = DraftRun.new(1)
            -- The first PARTY_MAX units field into the formation.
            for _ = 1, DraftRun.PARTY_MAX do
                assert(DraftRun.addUnit(run, Character.instantiate("character_knight")), "a formation cell is free")
            end
            assert(DraftRun.formationFull(run), "the formation is full")
            assert(#run.bench == 0, "and nothing has spilled to the bench yet")

            -- The next BENCH_MAX units spill to the bench.
            for _ = 1, DraftRun.BENCH_MAX do
                assert(DraftRun.addUnit(run, Character.instantiate("character_knight")), "a bench seat is free")
            end
            assert(DraftRun.benchFull(run), "the bench is full")
            assert(DraftRun.addUnit(run, Character.instantiate("character_knight")) == false,
                "with both full, drafting is refused")
        end,
    },
    {
        name = "the fielded party reads the formation front-row-first, with parallel seating slots",
        fn = function()
            local run = DraftRun.new(1)
            local a = Character.instantiate("character_knight")
            local b = Character.instantiate("character_knight")
            -- Place b on the FRONT row (cell 1) and a on the BACK row (cell 5).
            run.formation[5] = a
            run.formation[1] = b
            local party = DraftRun.party(run)
            assert(#party == 2 and party[1] == b and party[2] == a, "party is ordered by cell (front first)")
            local slots = DraftRun.formationSlots(run)
            assert(slots[1].row == 1 and slots[2].row == 2, "seating slots run parallel to the party")
        end,
    },
    {
        name = "arranging: bench<->formation and cell swaps keep the fielded count honest",
        fn = function()
            local run = DraftRun.new(1)
            local a = Character.instantiate("character_knight")
            local b = Character.instantiate("character_knight")
            DraftRun.addUnit(run, a) -- fields into cell 1
            DraftRun.addUnit(run, b) -- fields into cell 2

            -- Demote a to the bench, then field it back.
            assert(DraftRun.benchUnit(run, a), "a fielded unit benches")
            assert(DraftRun.cellOf(run, a) == nil and run.bench[1] == a, "a is now a reserve")
            assert(DraftRun.formationCount(run) == 1, "one fielder left")
            assert(DraftRun.fieldUnit(run, a), "and it fields back into a free cell")
            assert(DraftRun.formationCount(run) == 2, "two fielders again")

            -- Swap two occupied cells: placing b onto a's cell trades their positions.
            local cellA, cellB = DraftRun.cellOf(run, a), DraftRun.cellOf(run, b)
            DraftRun.placeInCell(run, b, cellA)
            assert(DraftRun.cellOf(run, b) == cellA and DraftRun.cellOf(run, a) == cellB, "the two cells swapped")
            assert(DraftRun.formationCount(run) == 2, "still two fielders")
        end,
    },
    {
        name = "a bench unit dropped onto an empty cell is refused when the formation is already full",
        fn = function()
            local run = DraftRun.new(1)
            for _ = 1, DraftRun.PARTY_MAX do DraftRun.addUnit(run, Character.instantiate("character_knight")) end
            local spare = Character.instantiate("character_knight")
            DraftRun.addUnit(run, spare) -- spills to the bench (formation full)
            assert(run.bench[1] == spare, "the spare is benched")
            local emptyCell = DraftRun.PARTY_MAX + 1 -- a back-row cell no fielder occupies
            assert(run.formation[emptyCell] == nil, "that cell is genuinely empty")
            assert(DraftRun.placeInCell(run, spare, emptyCell) == false, "fielding a fifth is refused")
            assert(run.bench[1] == spare, "and the spare stays on the bench")
        end,
    },
    {
        name = "a run snapshots to plain data and restores to the same formation, bench, gold and score",
        fn = function()
            local run = DraftRun.new(777)
            run.wins, run.losses, run.round, run.gold = 4, 1, 6, 17
            local knight = Character.instantiate("character_knight")
            knight.level = 3
            run.formation[3] = knight -- fielded on a specific cell
            DraftRun.addUnit(run, Character.instantiate("character_mage")) -- fields into a free cell

            -- Round-trips through the save encoder (scalar-only) exactly as the real disk path would.
            local snap = DraftRun.snapshot(run)
            local decoded = Save.decode("return " .. Save.encode(snap, 0))
            local back = DraftRun.restore(decoded)

            assert(back.wins == 4 and back.losses == 1, "score survives")
            assert(back.round == 6 and back.gold == 17, "round and wallet survive")
            assert(back.formation[3] and back.formation[3].id == "character_knight",
                "the fielded knight reloads on its exact cell")
            assert(back.formation[3].level == 3, "at its leveled state")
            assert(DraftRun.formationCount(back) == 2, "both fielders survive")
        end,
    },
    {
        name = "a pre-formation save (flat bench) upgrades cleanly, seating the first four",
        fn = function()
            -- The old snapshot shape: a flat `bench` of every drafted unit, no `formation` field.
            local legacy = {
                round = 3, wins = 2, losses = 1, gold = 9,
                bench = {
                    { id = "character_knight" }, { id = "character_mage" },
                    { id = "character_knight" }, { id = "character_mage" },
                    { id = "character_knight" }, -- a fifth, which must land on the (new) bench
                },
            }
            local back = DraftRun.restore(legacy)
            assert(DraftRun.formationCount(back) == DraftRun.PARTY_MAX, "the first four field")
            assert(#back.bench == 1, "and the fifth becomes a reserve")
        end,
    },
    {
        name = "the party mends between rounds: wounds, spent mana and a felled unit all come back",
        fn = function()
            local run = DraftRun.new(1)
            local fielder = DraftChassis.instantiate("character_knight")
            local reserve = DraftChassis.instantiate("character_mage")
            DraftRun.addUnit(run, fielder)
            DraftRun.addUnit(run, reserve)
            DraftRun.benchUnit(run, reserve)

            fielder.stats.health.current = 0 -- fell in the fight
            if type(reserve.stats.mana) == "table" then reserve.stats.mana.current = 0 end
            reserve.stats.health.current = 1

            DraftRun.recordResult(run, "loss")
            assert(fielder.stats.health.current == fielder.stats.health.max,
                "a felled fielder stands at full health for the next round")
            assert(reserve.stats.health.current == reserve.stats.health.max,
                "the bench mends too -- it is next round's team")
            if type(reserve.stats.mana) == "table" then
                assert(reserve.stats.mana.current == reserve.stats.mana.max, "and its mana is full again")
            end
        end,
    },
    {
        name = "a decided run does not mend -- the rollover it skips is the one that would have",
        fn = function()
            local run = DraftRun.new(1)
            local knight = DraftChassis.instantiate("character_knight")
            DraftRun.addUnit(run, knight)
            run.wins = DraftRun.WIN_TARGET
            knight.stats.health.current = 1

            DraftRun.recordResult(run, "win")
            assert(knight.stats.health.current == 1, "no round follows a finished run, so nothing rolls over")
        end,
    },
    {
        name = "consumables refill between rounds: a stack drunk dry marches out full again",
        fn = function()
            local run = DraftRun.new(1)
            local knight = DraftChassis.instantiate("character_knight") -- stripped, as a drafted unit is
            DraftRun.addUnit(run, knight)

            local potion = Item.instantiate("consumable_healing_potion", 2)
            Character.addItem(knight, potion)
            local weapon = Item.instantiate("weapon_iron_sword")
            Character.addItem(knight, weapon)
            local stashed = Item.instantiate("consumable_mana_potion", 1)
            run.stash = { stashed }

            DraftRun.stockConsumables(run) -- the party marches out
            potion.quantity = 0            -- and drinks both charges in the fight
            stashed.quantity = 0           -- (a stowed stack can be re-equipped, so it restocks too)

            DraftRun.recordResult(run, "win")
            assert(potion.quantity == 2, "the equipped stack comes back at its marching count")
            assert(stashed.quantity == 1, "and so does the one in the stash")
            assert(weapon.quantity == 1, "a non-stackable is untouched")
        end,
    },
    {
        name = "restocking never inflates a stack past what it marched out with",
        fn = function()
            local run = DraftRun.new(1)
            local knight = DraftChassis.instantiate("character_knight")
            DraftRun.addUnit(run, knight)
            local potion = Item.instantiate("consumable_healing_potion", 1)
            Character.addItem(knight, potion)

            DraftRun.stockConsumables(run)
            DraftRun.recordResult(run, "win")
            assert(potion.quantity == 1, "an unspent stack stays where it is")

            -- A stack bought AFTER the last fight has no stamp yet; the rollover must leave it alone
            -- rather than zeroing it.
            local bought = Item.instantiate("consumable_mana_potion", 3)
            Character.addItem(knight, bought)
            DraftRun.recordResult(run, "win")
            assert(bought.quantity == 3, "an un-stamped stack is left exactly as bought")
        end,
    },
    {
        name = "a benched unit's consumables restock too -- the bench is where next round's team waits",
        fn = function()
            local run = DraftRun.new(1)
            local reserve = DraftChassis.instantiate("character_knight")
            DraftRun.addUnit(run, reserve)
            DraftRun.benchUnit(run, reserve)
            local potion = Item.instantiate("consumable_healing_potion", 2)
            Character.addItem(reserve, potion)

            DraftRun.stockConsumables(run)
            potion.quantity = 1 -- fielded mid-run, drank one
            DraftRun.recordResult(run, "win")
            assert(potion.quantity == 2, "the reserve's stack refills as a fielder's does")
        end,
    },
}
