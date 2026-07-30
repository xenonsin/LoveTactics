-- Tests for models/draft_run.lua: the Draft-mode run loop -- budget, the win/loss ladder, the
-- draftable pool that grows by round, and snapshot round-tripping. Pure logic, runs headless.

local DraftRun = require("models.draft_run")
local Save = require("models.save")
local Character = require("models.character")

return {
    {
        name = "a fresh run opens at round 1 with the opening budget and an empty bench",
        fn = function()
            local run = DraftRun.new(123)
            assert(run.round == 1, "starts at round 1")
            assert(run.wins == 0 and run.losses == 0, "no results yet")
            assert(run.gold == DraftRun.roundBudget(1), "granted the round-1 budget")
            assert(#run.bench == 0, "nothing drafted yet")
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
        name = "the bench fills to a cap and then refuses more",
        fn = function()
            local run = DraftRun.new(1)
            for _ = 1, DraftRun.BENCH_MAX do
                assert(DraftRun.addUnit(run, Character.instantiate("character_knight")), "a seat is free")
            end
            assert(DraftRun.benchFull(run), "the bench is full")
            assert(DraftRun.addUnit(run, Character.instantiate("character_knight")) == false, "and refuses more")
        end,
    },
    {
        name = "a run snapshots to plain data and restores to the same bench, gold and score",
        fn = function()
            local run = DraftRun.new(777)
            run.wins, run.losses, run.round, run.gold = 4, 1, 6, 17
            local knight = Character.instantiate("character_knight")
            knight.level = 3
            DraftRun.addUnit(run, knight)

            -- Round-trips through the save encoder (scalar-only) exactly as the real disk path would.
            local snap = DraftRun.snapshot(run)
            local decoded = Save.decode("return " .. Save.encode(snap, 0))
            local back = DraftRun.restore(decoded)

            assert(back.wins == 4 and back.losses == 1, "score survives")
            assert(back.round == 6 and back.gold == 17, "round and wallet survive")
            assert(#back.bench == 1 and back.bench[1].id == "character_knight", "the bench survives")
            assert(back.bench[1].level == 3, "at its leveled state")
        end,
    },
}
