-- THE HALL IS STOCKED BY THE PEOPLE YOU TURNED DOWN (models/descent_recruit.lua's Recruit.decline /
-- hallSlate / join).
--
-- The hall does not deal a fresh slate off the pool. It offers the bodies you walked past on the floors,
-- which makes it a consequence rather than a shop -- passing on somebody is a decision you meet again.
--
-- Two things about that rule are easy to get wrong and both are pinned here:
--   * NOTHING ELSE MAY BE IN IT. A fresh save has refused nobody and the hall is EMPTY -- it carried a
--     three-body authored starter slate for a while, which is a shop wearing a consequence's clothes:
--     it hands over bodies the player never met, which is the one thing this list exists to prevent.
--   * HIRING SOMEBODY MUST UN-REFUSE THEM. A body in the company standing in the hall waiting to be
--     hired is the same person twice.

local Character = require("models.character")
local Recruit = require("models.descent_recruit")

-- A profile-shaped stand-in: the hall reads only these two fields.
local function profile()
    return { roster = {}, declined = {} }
end

local function has(list, id)
    for _, held in ipairs(list) do
        if held == id then return true end
    end
    return false
end

return {
    {
        name = "a hall nobody has refused is empty",
        fn = function()
            local p = profile()
            assert(#Recruit.hallSlate(p) == 0,
                "the hall stocks itself from below -- a player who has refused nobody may hire nobody")
            assert(Recruit.STARTER == nil,
                "the authored starter slate is gone: it offered bodies the player had never met")
        end,
    },
    {
        name = "a refusal is the only thing that stocks the hall",
        fn = function()
            local p = profile()
            Recruit.decline(p, "character_zosia")
            local slate = Recruit.hallSlate(p)
            assert(#slate == 1 and slate[1] == "character_zosia",
                "the refused body is the stock, and the whole of it")
        end,
    },
    {
        name = "refusing the same body twice does not stock two of them",
        fn = function()
            local p = profile()
            Recruit.decline(p, "character_vess")
            Recruit.decline(p, "character_vess")
            assert(#Recruit.hallSlate(p) == 1, "one body, however many times you walked past it")
        end,
    },
    {
        name = "hiring somebody takes them out of the hall",
        fn = function()
            local p = profile()
            Recruit.decline(p, "character_pim")
            Recruit.decline(p, "character_cass")
            assert(#Recruit.hallSlate(p) == 2, "both are waiting")

            Recruit.join(p, "character_pim")
            local slate = Recruit.hallSlate(p)
            assert(not has(slate, "character_pim"),
                "a body in the company must not also be standing in the hall")
            assert(has(slate, "character_cass"), "and the other one is still there")
            -- Cleared from the record itself, not merely filtered out of the view: the list is the
            -- honest account of who is still out there.
            assert(not has(p.declined, "character_pim"), "the refusal was cleared, not hidden")
        end,
    },
    {
        name = "the hall never offers a name it cannot build",
        fn = function()
            local p = profile()
            Recruit.decline(p, "character_a_body_that_was_deleted")
            Recruit.decline(p, "character_nell")
            local slate = Recruit.hallSlate(p)
            -- A slate rides in the save and can outlive a blueprint that was renamed or removed, so the
            -- dead id is dropped here rather than opening a card that does nothing when pressed.
            assert(#slate == 1 and slate[1] == "character_nell", "the vanished id is dropped")
        end,
    },
    {
        name = "everything the hall can ever hold is somebody, never a template",
        fn = function()
            -- The hall's stock is whatever the floors offered and the player refused, so this is really
            -- an assertion about the FLOORS: nothing a stop can put in front of the player may be a
            -- generic class template (character_fighter, character_knight), because those are stat lines
            -- rather than people and the hall would be stocked with them a floor later.
            --
            -- THE BOUND RELIC IS THE TEST, and it is the data's own distinction rather than one invented
            -- here: a template is exactly the base a named body sharpens, and what it lacks is the relic
            -- (see character_rogue's own header). It catches both halves at once -- the seven base
            -- classes are met as Saber and Clem, who have one, and never as Fighter and Rogue, who do
            -- not -- and it cannot be satisfied by renaming anything.
            local Item = require("models.item")
            local pool = Recruit.pool(1000)
            assert(#pool > 0, "somebody is down there")
            -- NOT `boss`, which was the obvious test and is the wrong one: Amana is a companion the
            -- Cathedral fields against you before she joins, so she carries the flag and is still very
            -- much somebody. What separates a person from a template is the relic, not the fight.
            for _, id in ipairs(pool) do
                local def = Character.defs[id]
                assert(def, id .. ": the pool names a body that does not exist")

                local relic
                for _, entry in ipairs(def.startingItems or {}) do
                    local itemId = type(entry) == "table" and entry.id or entry
                    local item = type(itemId) == "string" and Item.defs[itemId]
                    if item and item.bound then relic = itemId end
                end
                assert(relic, id .. ": carries no bound relic, so it is a class template rather than"
                    .. " somebody -- the floors offer people")
            end

            -- And the templates by name, because that is the instruction in its plainest form.
            local held = {}
            for _, id in ipairs(pool) do held[id] = true end
            for _, id in ipairs({ "character_fighter", "character_knight", "character_rogue",
                "character_mage", "character_priest", "character_alchemist", "character_archer" }) do
                assert(not held[id], id .. " is a generic class template and must never be offered")
            end
        end,
    },
}
