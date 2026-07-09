return {
    gold = 0,
    prestige = 1,
    -- Every character the player owns (unlimited size).
    startingRoster = { "knight", "mage", "archer", "priest" }, -- character ids
    -- The active party: a subset of the roster, capped at Player.MAX_PARTY.
    startingParty = { "knight", "mage", "archer", "priest" }, -- character ids
}
