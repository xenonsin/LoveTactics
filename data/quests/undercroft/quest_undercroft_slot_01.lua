-- CLEM'S VAULT. A vault door in the rift carries the Bank's own mark, and behind it is a keeper who
-- counts footsteps for a living. The gold is the company's; the ledgers are going in a fire.
--
-- RESTORED 2026-10-14 (data/quests went in 92ff549d, and with it every way a companion could join).
-- SHE IS MET IN GREED, the Undercroft's own circle (Descent.SINS' `vendor`, Descent.dealCompanion), so
-- the vault is held by that circle's own people: the dwarves who mine and hoard it. It was a bandit chief
-- and his champions, and the rift fields no bandit any more.
--
--   * THE KEEPER IS THE GOLDSMITH, the line's support -- the one who counts. It does not stand at the
--     door; it stands behind it, which is what makes `assassinate` on it a job rather than a rush.
--   * THE HEARTHGUARD walks beside whoever is going for the gold (its own rule), so the keeper's guard
--     is the body that already guards the counting dwarf.
--   * A DELVER comes up out of the floor on the circle's second floor -- the vault grows a back door.
--
-- NO GOODS: the Cutpurse Coat is on the mammonite ladder now (rung 4). The purse stays.
return {
    name = "The Vault Beneath",
    description = "A vault door in the rift carries the Bank's own mark. Three doors, two keys, and " ..
        "a keeper behind the last one who is still counting.",
    difficulty = "Normal",
    sponsor = "undercroft",
    outro = "conversation_undercroft_slot_01_outro",
    rewardGold = 150,
    rewardCharacter = "character_clem",
    -- READ ONLY BY models/balance.lua, which still measures a quest's bodies at a campaign standing:
    -- the standing at the first floor of the circle she is met in (Greed, floor five on the authored order),
    -- so a deep circle's stock is judged against the company that actually meets it.
    requiredPrestige = 4,
    map = {
        -- The ground of that circle. The descent picks its own ground off the floor, so this is the
        -- authored claim tests/biome_spec.lua validates, not what draws the board.
        biome = "cave",
        objective = {
            name = "The Vault Door",
            composition = function(ctx)
                local list = { "character_dwarf_goldsmith", "character_dwarf_hearthguard",
                    "character_dwarf_hearthguard" }
                if require("models.descent").floorWithinCircle(ctx.depth or 1) >= 2 then
                    list[#list + 1] = "character_dwarf_delver"
                end
                return list
            end,
            win = { type = "assassinate", target = "character_dwarf_goldsmith",
                enemy = "the vault's keeper" },
        },
    },
}
