-- Offline conformance tests for the pure CrabSyncV2 data plane.
-- Run from the repository root with Lua 5.4:
--   lua tests/crabsyncv2_core_test.lua

_G.CRABSYNCV2_TEST_MODE = true

local okLoad, loadError = pcall(dofile, "client/Mods/CrabSyncV2/Scripts/main.lua")
if not okLoad then
    io.stderr:write("not ok - failed to load main.lua in CRABSYNCV2_TEST_MODE: " .. tostring(loadError) .. "\n")
    os.exit(1)
end

local api = _G.CrabSyncV2 and _G.CrabSyncV2.test
if type(api) ~= "table" then
    io.stderr:write("not ok - _G.CrabSyncV2.test was not exposed\n")
    os.exit(1)
end

for _, name in ipairs({
    "normalizeSnapshot",
    "mergeSnapshots",
    "encodeCarrierBlocks",
    "decodeCarrierBlock",
    "assembleCarrierBlocks",
}) do
    if type(api[name]) ~= "function" then
        io.stderr:write("not ok - missing _G.CrabSyncV2.test." .. name .. "\n")
        os.exit(1)
    end
end

local NOW_MS = 1730000000000
local UINT32_MAX = 4294967295
local testsRun = 0
local failures = 0

local function fail(message)
    error(message or "assertion failed", 2)
end

local function assertTrue(value, message)
    if not value then fail(message or "expected truthy value") end
end

local function assertNil(value, message)
    if value ~= nil then fail((message or "expected nil") .. "; got " .. tostring(value)) end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail(string.format("%s; expected=%s actual=%s", message or "values differ", tostring(expected), tostring(actual)))
    end
end

local function sortedKeys(value)
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(left, right)
        if type(left) == type(right) then return left < right end
        return type(left) < type(right)
    end)
    return keys
end

local function stableRepr(value, seen)
    local valueType = type(value)
    if valueType == "nil" then return "nil" end
    if valueType == "boolean" or valueType == "number" then return tostring(value) end
    if valueType == "string" then return string.format("%q", value) end
    if valueType ~= "table" then return "<" .. valueType .. ">" end
    seen = seen or {}
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local parts = {}
    for _, key in ipairs(sortedKeys(value)) do
        parts[#parts + 1] = "[" .. stableRepr(key, seen) .. "]=" .. stableRepr(value[key], seen)
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

local function assertDeepEqual(actual, expected, message)
    local actualRepr = stableRepr(actual)
    local expectedRepr = stableRepr(expected)
    if actualRepr ~= expectedRepr then
        fail(string.format("%s\nexpected: %s\nactual:   %s", message or "tables differ", expectedRepr, actualRepr))
    end
end

local function clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[clone(key, seen)] = clone(item, seen) end
    return result
end

local function baseSnapshot(source, timestampMs)
    source = source or "peer-a"
    return {
        protocolVersion = 2,
        sessionId = "session-01",
        clientInstanceId = "client-" .. source,
        sourcePlayerFingerprint = source,
        sourceRole = "joined",
        lifecycleGeneration = 7,
        timestampMs = timestampMs or (NOW_MS - 100),
        tick = 120,
        visibilityClass = "peer_visible",
        evidenceConfidence = "runtime_safe_remote_visible",
        transportMode = "game_visible",
        partial = false,
        health = {
            supported = true,
            currentHealth = 100.5,
            currentMaxHealth = 150.5,
            baseMaxHealth = 100,
            maxHealthMultiplier = 1.5,
            armorSupported = false,
            unsupportedFields = { "armor" },
        },
        equipment = {
            supported = true,
            weapon = { supported = true, shortName = "DA_Weapon_AutoRifle", fullName = "/Game/Weapons/DA_Weapon_AutoRifle.DA_Weapon_AutoRifle" },
            ability = { supported = true, shortName = "DA_Ability_BlackHole" },
            melee = { supported = true, shortName = "DA_Melee_Hammer" },
            unsupportedFields = {},
        },
        resources = {
            supported = true,
            crystals = 25,
            slots = { weaponMods = 2, abilityMods = 3, meleeMods = 4, perks = 5 },
            keysSupported = false,
            unsupportedFields = { "keys" },
        },
        inventory = {
            supported = true,
            categorySupported = {
                weaponMods = true,
                abilityMods = true,
                meleeMods = true,
                perks = true,
                relics = true,
            },
            weaponMods = {},
            abilityMods = {},
            meleeMods = {},
            perks = {},
            relics = {},
            unsupportedFields = {},
        },
        unsupportedFields = {},
    }
end

local function test(name, body)
    testsRun = testsRun + 1
    local ok, err = pcall(body)
    if ok then
        io.write("ok " .. testsRun .. " - " .. name .. "\n")
    else
        failures = failures + 1
        io.stderr:write("not ok " .. testsRun .. " - " .. name .. "\n  " .. tostring(err) .. "\n")
    end
end

test("normalization clamps resources and levels while preserving signed metadata", function()
    local raw = baseSnapshot()
    raw.resources.crystals = UINT32_MAX + 1000
    raw.resources.slots = {
        weaponMods = -9,
        abilityMods = 999,
        meleeMods = 4.9,
        perks = 6,
    }
    raw.inventory.weaponMods = {
        {
            category = "weaponMods",
            i = 0,
            n = "DA_WeaponMod_First",
            d = "/Game/Mods/DA_WeaponMod_First.DA_WeaponMod_First",
            l = 0,
            a = -12.5,
            e = { 7, 1, 7 },
            metadataStatus = "ok",
        },
        {
            category = "weaponMods",
            i = 1,
            n = "DA_WeaponMod_Second",
            l = 999,
            a = 2.25,
            e = { 4 },
            metadataStatus = "ok",
        },
    }

    local normalized, reason = api.normalizeSnapshot(raw, NOW_MS)
    assertTrue(normalized, "snapshot should normalize: " .. tostring(reason))
    assertEqual(normalized.resources.crystals, UINT32_MAX, "crystals clamp to UInt32")
    assertEqual(normalized.resources.slots.weaponMods, 0, "negative byte clamps to zero")
    assertEqual(normalized.resources.slots.abilityMods, 255, "large byte clamps to 255")
    assertEqual(normalized.resources.slots.meleeMods, 4, "slot count is integral")

    local first = normalized.inventory.weaponMods[1]
    local second = normalized.inventory.weaponMods[2]
    assertEqual(first.level, 1, "item level clamps to minimum")
    assertEqual(second.level, 255, "item level clamps to byte maximum")
    assertEqual(first.accumulatedBuff, -12.5, "signed accumulated buff is preserved")
    assertTrue(first.accumulatedBuffKnown, "signed accumulated buff remains known")
    assertDeepEqual(first.enhancements, { 7, 1, 7 }, "enhancement order and multiplicity are preserved")
    assertEqual(first.daFullName, "/Game/Mods/DA_WeaponMod_First.DA_WeaponMod_First", "full DA identity is preserved")
end)

test("unknown metadata stays unknown and observed empty enhancements stay known", function()
    local raw = baseSnapshot()
    raw.inventory.perks = {
        {
            category = "perks",
            n = "DA_Perk_UnknownMetadata",
            metadataStatus = "unsupported",
            unsupportedFields = { "InventoryInfo.Level", "InventoryInfo.AccumulatedBuff", "InventoryInfo.Enhancements" },
        },
        {
            category = "perks",
            n = "DA_Perk_ObservedEmpty",
            l = 1,
            a = 0,
            e = {},
            metadataStatus = "ok",
        },
    }

    local normalized, reason = api.normalizeSnapshot(raw, NOW_MS)
    assertTrue(normalized, "snapshot should normalize: " .. tostring(reason))
    local unknown = normalized.inventory.perks[1]
    local observed = normalized.inventory.perks[2]
    assertNil(unknown.level, "unknown level must not become 1")
    assertEqual(unknown.levelKnown, false, "unknown level marker")
    assertNil(unknown.accumulatedBuff, "unknown accumulated buff must not become 0")
    assertEqual(unknown.accumulatedBuffKnown, false, "unknown accumulated buff marker")
    assertNil(unknown.enhancements, "unknown enhancements must not become empty")
    assertEqual(unknown.enhancementsKnown, false, "unknown enhancements marker")
    assertEqual(unknown.metadataStatus, "unsupported", "metadata status is preserved")
    assertTrue(type(unknown.unsupportedFields) == "table" and #unknown.unsupportedFields == 3,
        "unsupported field details are preserved")
    assertTrue(observed.enhancementsKnown, "observed empty enhancements are known")
    assertTrue(type(observed.enhancements) == "table" and #observed.enhancements == 0,
        "observed empty enhancements remain an empty table")
end)

test("duplicate same-name instances survive normalization and merge independently", function()
    local raw = baseSnapshot()
    raw.inventory.relics = {
        {
            category = "relics",
            i = 3,
            n = "DA_Relic_Duplicate",
            d = "/Game/Relics/DA_Relic_Duplicate.DA_Relic_Duplicate",
            l = 2,
            a = -4.5,
            e = { 1 },
            metadataStatus = "ok",
        },
        {
            category = "relics",
            i = 8,
            n = "DA_Relic_Duplicate",
            d = "/Game/Relics/DA_Relic_Duplicate.DA_Relic_Duplicate",
            l = 9,
            a = 14.25,
            e = { 4, 7 },
            metadataStatus = "ok",
        },
    }

    local merged, report = api.mergeSnapshots({ raw }, NOW_MS)
    assertTrue(merged, "merge should succeed: " .. stableRepr(report))
    assertEqual(#merged.inventory.relics, 2, "same-name instances must not collapse")
    assertEqual(merged.inventory.relics[1].index, 3, "first instance index survives")
    assertEqual(merged.inventory.relics[1].accumulatedBuff, -4.5, "first instance signed buff survives")
    assertDeepEqual(merged.inventory.relics[1].enhancements, { 1 }, "first instance enhancements survive")
    assertEqual(merged.inventory.relics[2].index, 8, "second instance index survives")
    assertEqual(merged.inventory.relics[2].level, 9, "second instance level survives")
    assertDeepEqual(merged.inventory.relics[2].enhancements, { 4, 7 }, "second instance enhancements survive")
    assertEqual(report.policies.inventory, "preserve_instances", "merge reports instance-preserving policy")
end)

test("inventory merge preserves every source instance without collapsing exact duplicates", function()
    local peerA = baseSnapshot("peer-a")
    peerA.inventory.weaponMods = {
        { category = "weaponMods", i = 0, n = "DA_WeaponMod_Shared", d = "/Game/Mods/DA_WeaponMod_Shared.DA_WeaponMod_Shared", l = 5, a = -2.5, e = { 1, 4 } },
        { category = "weaponMods", i = 1, n = "DA_WeaponMod_Shared", d = "/Game/Mods/DA_WeaponMod_Shared.DA_WeaponMod_Shared", l = 5, a = -2.5, e = { 1, 4 } },
        { category = "weaponMods", i = 2, n = "DA_WeaponMod_Unknown", metadataStatus = "unsupported" },
    }
    local peerB = baseSnapshot("peer-b")
    peerB.inventory.weaponMods = {
        { category = "weaponMods", i = 5, n = "DA_WeaponMod_Shared", d = "/Game/Mods/DA_WeaponMod_Shared.DA_WeaponMod_Shared", l = 5, a = -2.5, e = { 1, 4 } },
        { category = "weaponMods", i = 7, n = "DA_WeaponMod_Unknown", metadataStatus = "unsupported" },
    }

    local merged, report = api.mergeSnapshots({ peerB, peerA }, NOW_MS)
    assertTrue(merged, "merge should succeed: " .. stableRepr(report))
    local shared, unknown = {}, {}
    for _, item in ipairs(merged.inventory.weaponMods) do
        if item.daShortName == "DA_WeaponMod_Shared" then shared[#shared + 1] = item
        elseif item.daShortName == "DA_WeaponMod_Unknown" then unknown[#unknown + 1] = item end
    end
    assertEqual(#shared, 3, "independent exact duplicates remain separate source instances")
    table.sort(shared, function(left, right) return (left.index or -1) < (right.index or -1) end)
    assertEqual(shared[1].index, 0, "first peer's first duplicate ordinal is retained")
    assertEqual(shared[2].index, 1, "first peer's second duplicate ordinal is retained")
    assertEqual(shared[3].index, 5, "second peer's identical instance is not collapsed")
    assertDeepEqual(shared[1].enhancements, { 1, 4 }, "exact metadata survives source-preserving merge")
    assertDeepEqual(shared[2].enhancements, { 1, 4 }, "duplicate metadata survives independently")
    assertDeepEqual(shared[3].enhancements, { 1, 4 }, "cross-peer duplicate metadata survives independently")
    assertEqual(#unknown, 2, "unknown metadata remains source-scoped instead of cross-peer collapsed")
    assertTrue(#merged.inventory.unsupportedFields > 0, "unknown metadata marks inventory unsafe for apply")
end)

test("snapshot admission requires explicit protocol, timestamp, and lifecycle generation", function()
    local missingProtocol = baseSnapshot("missing-protocol")
    missingProtocol.protocolVersion = nil
    local normalized, reason = api.normalizeSnapshot(missingProtocol, NOW_MS)
    assertNil(normalized, "missing protocol must not be invented")
    assertEqual(reason, "missing protocol", "missing protocol reason")

    local missingTimestamp = baseSnapshot("missing-timestamp")
    missingTimestamp.timestampMs = nil
    normalized, reason = api.normalizeSnapshot(missingTimestamp, NOW_MS)
    assertNil(normalized, "missing timestamp must not inherit receiver time")
    assertEqual(reason, "missing timestamp", "missing timestamp reason")

    local missingGeneration = baseSnapshot("missing-generation")
    missingGeneration.lifecycleGeneration = nil
    normalized, reason = api.normalizeSnapshot(missingGeneration, NOW_MS)
    assertNil(normalized, "missing generation must not become zero")
    assertEqual(reason, "missing lifecycle generation", "missing generation reason")

    local fractionalProtocol = baseSnapshot("fractional-protocol")
    fractionalProtocol.protocolVersion = 2.5
    normalized, reason = api.normalizeSnapshot(fractionalProtocol, NOW_MS)
    assertNil(normalized, "fractional protocol must not be truncated to v2")
    assertEqual(reason, "invalid protocol", "fractional protocol reason")

    local fractionalGeneration = baseSnapshot("fractional-generation")
    fractionalGeneration.lifecycleGeneration = 7.5
    normalized, reason = api.normalizeSnapshot(fractionalGeneration, NOW_MS)
    assertNil(normalized, "fractional generation must not be truncated")
    assertEqual(reason, "invalid lifecycle generation", "fractional generation reason")
end)

test("invalid enhancement sequences become unknown instead of being truncated or clamped", function()
    local raw = baseSnapshot("bad-enhancements")
    raw.inventory.perks = {
        { category = "perks", n = "DA_Perk_Bad", l = 3, a = -2, e = { 1, "bad", 7 }, metadataStatus = "ok" },
        { category = "perks", n = "DA_Perk_Range", l = 3, a = -2, e = { 28 }, metadataStatus = "ok" },
    }
    local normalized, reason = api.normalizeSnapshot(raw, NOW_MS)
    assertTrue(normalized, "snapshot remains usable with explicitly unknown item metadata: " .. tostring(reason))
    for _, item in ipairs(normalized.inventory.perks) do
        assertEqual(item.enhancementsKnown, false, "malformed/out-of-enum enhancement sequence is unknown")
        assertNil(item.enhancements, "invalid enhancement elements are not dropped into a plausible array")
        assertEqual(item.metadataStatus, "partial", "remaining known scalar metadata is marked partial")
        assertTrue(#item.unsupportedFields > 0, "invalid sequence carries an unsupported marker")
    end
end)

test("inventory completeness and item provenance require explicit envelope-backed proof", function()
    local raw = baseSnapshot("peer-proof")
    raw.inventory.categorySupported = { weaponMods = true }
    raw.inventory.abilityMods = nil
    raw.inventory.meleeMods = nil
    raw.inventory.perks = nil
    raw.inventory.relics = nil
    raw.inventory.weaponMods = {
        {
            category = "perks",
            sourcePlayer = "spoofed-source",
            visibilityClass = "host_only_candidate",
            lifecycleGeneration = 999,
            n = "DA_WeaponMod_Proof",
            d = "/Game/Mods/DA_WeaponMod_Proof.DA_WeaponMod_Proof",
            l = 1,
            a = 0,
            e = {},
        },
    }
    local normalized, reason = api.normalizeSnapshot(raw, NOW_MS)
    assertTrue(normalized, "explicit weapon-mod category should normalize: " .. tostring(reason))
    assertTrue(normalized.inventory.categorySupported.weaponMods, "explicit present category is supported")
    for _, key in ipairs({ "abilityMods", "meleeMods", "perks", "relics" }) do
        assertEqual(normalized.inventory.categorySupported[key], false, "omitted category is not invented as an observed empty array: " .. key)
    end
    local item = normalized.inventory.weaponMods[1]
    assertEqual(item.category, "weaponMods", "category is canonicalized from its envelope slot")
    assertEqual(item.sourcePlayer, "peer-proof", "item source is canonicalized from snapshot fingerprint")
    assertEqual(item.visibilityClass, "peer_visible", "item visibility is canonicalized from snapshot visibility")
    assertEqual(item.lifecycleGeneration, 7, "item generation is canonicalized from snapshot generation")

    local legacy = baseSnapshot("peer-legacy")
    legacy.inventory.categorySupported = nil
    normalized = assert(api.normalizeSnapshot(legacy, NOW_MS))
    assertEqual(normalized.inventory.supported, false, "legacy aggregate supported flag is not category-completeness proof")

    local inconsistent = baseSnapshot("peer-count-mismatch")
    inconsistent.inventory.weaponMods = { { n = "DA_WeaponMod_Count", d = "/Game/Mods/DA_WeaponMod_Count.DA_WeaponMod_Count", l = 1, a = 0, e = {} } }
    inconsistent.inventory.counts = { weaponMods = 0 }
    normalized = assert(api.normalizeSnapshot(inconsistent, NOW_MS))
    assertEqual(normalized.inventory.categorySupported.weaponMods, false, "mismatched count cannot prove category completeness")
end)

test("health merge preserves signed observations, unknown optionals, and armor evidence", function()
    local raw = baseSnapshot("health-edge")
    raw.health.currentHealth = -5
    raw.health.currentMaxHealth = -1
    raw.health.baseMaxHealth = nil
    raw.health.maxHealthMultiplier = nil
    raw.health.armorObserved = true
    raw.health.armor = { currentPlates = 2, currentPlateHealth = 31.5, previousPlateHealth = 40 }
    local merged, report = api.mergeSnapshots({ raw }, NOW_MS)
    assertTrue(merged, "health edge snapshot should merge: " .. stableRepr(report))
    assertEqual(merged.health.currentHealth, -5, "finite signed current health is not silently changed to zero")
    assertEqual(merged.health.currentMaxHealth, -1, "finite signed max health is not silently changed to zero")
    assertNil(merged.health.baseMaxHealth, "unknown base max remains unknown")
    assertNil(merged.health.maxHealthMultiplier, "unknown multiplier remains unknown")
    assertTrue(merged.health.armorObserved, "armor observation marker survives normalization and merge")
    assertEqual(#merged.health.armorObservations, 1, "unresolved armor evidence is retained per source")
end)

test("wrong-version, stale, future, and partial snapshots are rejected", function()
    local wrong = baseSnapshot("wrong")
    wrong.protocolVersion = 1
    local normalized, reason = api.normalizeSnapshot(wrong, NOW_MS)
    assertNil(normalized, "wrong protocol should be rejected")
    assertEqual(reason, "wrong protocol", "wrong protocol reason")

    local partial = baseSnapshot("partial")
    partial.partial = true
    local valid = baseSnapshot("valid")
    local stale = baseSnapshot("stale", NOW_MS - 15001)
    local future = baseSnapshot("future", NOW_MS + 5001)
    local merged, report = api.mergeSnapshots({ partial, stale, future, valid }, NOW_MS)
    assertTrue(merged, "one valid snapshot should still merge")
    assertEqual(report.accepted, 1, "only complete snapshot accepted")
    assertEqual(#report.rejected, 3, "partial, stale, and future snapshots reported")
    assertEqual(report.rejected[1].reason, "partial snapshot", "partial reason")
    assertEqual(report.rejected[2].reason, "stale snapshot", "stale reason")
    assertEqual(report.rejected[3].reason, "future timestamp", "future timestamp reason")
end)

test("merge rejects snapshots from a prior or different session", function()
    local current = baseSnapshot("peer-current")
    current.sessionId = "session-current"
    local prior = baseSnapshot("peer-prior")
    prior.sessionId = "session-prior"
    prior.resources.crystals = UINT32_MAX
    local missing = baseSnapshot("peer-missing")
    missing.sessionId = ""
    missing.resources.crystals = UINT32_MAX

    local merged, report = api.mergeSnapshots({ prior, missing, current }, NOW_MS, "session-current")
    assertTrue(merged, "current-session row should merge")
    assertEqual(report.accepted, 1, "cross-session and unscoped rows are not admitted")
    assertEqual(#report.rejected, 2, "session admission rejections are reported")
    assertEqual(report.rejected[1].reason, "session mismatch", "cross-session rejection reason")
    assertEqual(report.rejected[2].reason, "missing session fingerprint", "unscoped rejection reason")
    assertEqual(merged.sessionId, "session-current", "merged envelope remains in the expected session")
    assertEqual(merged.resources.crystals, current.resources.crystals,
        "prior-session resource state cannot overwrite the current session")
end)

test("merge rejects rows from an old lifecycle generation", function()
    local current = baseSnapshot("peer-current-generation")
    local old = baseSnapshot("peer-old-generation")
    old.lifecycleGeneration = 6
    old.resources.crystals = UINT32_MAX
    local merged, report = api.mergeSnapshots({ old, current }, NOW_MS, "session-01", 7)
    assertTrue(merged, "current-generation row should merge")
    assertEqual(report.accepted, 1, "old-generation row is not admitted")
    assertEqual(#report.rejected, 1, "generation rejection is reported")
    assertEqual(report.rejected[1].reason, "lifecycle generation mismatch", "generation rejection reason")
    assertEqual(merged.resources.crystals, current.resources.crystals, "old-generation state cannot overwrite current state")
end)

test("merge is repeatable and independent of input row order", function()
    local peerA = baseSnapshot("peer-a")
    peerA.sourceRole = "joined"
    peerA.resources.crystals = 12
    peerA.resources.slots = { weaponMods = 2, abilityMods = 7, meleeMods = 1, perks = 3 }
    peerA.inventory.weaponMods = {
        { category = "weaponMods", i = 2, n = "DA_WeaponMod_Zed", l = 2, a = -2, e = { 7 } },
    }

    local peerB = baseSnapshot("peer-b")
    peerB.sourceRole = "host"
    peerB.resources.crystals = 30
    peerB.resources.slots = { weaponMods = 8, abilityMods = 4, meleeMods = 6, perks = 2 }
    peerB.equipment.weapon.shortName = "DA_Weapon_HostChoice"
    peerB.inventory.weaponMods = {
        { category = "weaponMods", i = 0, n = "DA_WeaponMod_Alpha", l = 4, a = 1, e = { 1, 4 } },
    }

    local forward, forwardReport = api.mergeSnapshots({ peerA, peerB }, NOW_MS)
    local reverse, reverseReport = api.mergeSnapshots({ peerB, peerA }, NOW_MS)
    local repeated, repeatedReport = api.mergeSnapshots({ peerA, peerB }, NOW_MS)
    assertTrue(forward and reverse and repeated, "all merge permutations should succeed")
    assertDeepEqual(forward, reverse, "input permutation must not affect merged output")
    assertDeepEqual(forward, repeated, "repeated merge must be byte-for-byte deterministic as a Lua value")
    assertDeepEqual(forwardReport.policies, reverseReport.policies, "policy report must be deterministic")
    assertDeepEqual(forwardReport.policies, repeatedReport.policies, "repeated policy report must be deterministic")
    assertEqual(forward.resources.crystals, 30, "crystals use max_visible to avoid feedback")
    assertEqual(forward.resources.slots.weaponMods, 8, "slots use max_visible")
    assertEqual(forward.resources.slots.abilityMods, 7, "slot max is per category")
    assertEqual(forward.equipment.weapon.shortName, "DA_Weapon_AutoRifle", "lowest fingerprint equipment wins")
    assertEqual(#forward.inventory.weaponMods, 2, "inventory instances from both peers survive")
    assertEqual(forwardReport.policies.health, "max_visible", "health policy avoids feedback")
    assertEqual(forwardReport.policies.crystals, "max_visible", "crystal policy avoids feedback")
    assertEqual(forwardReport.policies.slots, "max_visible", "slot policy is explicit")
    assertEqual(forwardReport.policies.equipment, "lowest_fingerprint", "equipment policy is view-invariant")
end)

test("safer transport wins for duplicate source snapshots", function()
    local visible = baseSnapshot("peer-a", NOW_MS - 1000)
    visible.transportMode = "game_visible"
    visible.lifecycleGeneration = 4
    visible.resources.crystals = 9
    visible.inventory.perks = {
        { category = "perks", n = "DA_Perk_GameVisible", l = 1, a = -3, e = { 1 } },
    }

    local carrier = baseSnapshot("peer-a", NOW_MS - 10)
    carrier.transportMode = "p2p_carrier"
    carrier.lifecycleGeneration = 99
    carrier.resources.crystals = 777
    carrier.inventory.perks = {
        { category = "perks", n = "DA_Perk_Carrier", l = 255, a = 999, e = { 27 } },
    }

    local merged, report = api.mergeSnapshots({ carrier, visible }, NOW_MS)
    assertTrue(merged, "merge should succeed: " .. stableRepr(report))
    assertEqual(report.accepted, 1, "only one best row per source is accepted")
    assertEqual(merged.resources.crystals, 9, "newer carrier state cannot overwrite game-visible state")
    assertEqual(#merged.inventory.perks, 1, "only selected source row contributes")
    assertEqual(merged.inventory.perks[1].daShortName, "DA_Perk_GameVisible", "game-visible item survives")
end)

test("carrier codec performs deterministic multi-chunk round-trip", function()
    local snapshot = baseSnapshot("peer-codec")
    snapshot.inventory.weaponMods = {
        { category = "weaponMods", i = 0, n = "DA_WeaponMod_Codec", d = "/Game/Mods/DA_WeaponMod_Codec.DA_WeaponMod_Codec", l = 7, a = -8.75, e = { 1, 4, 7 } },
    }
    local opts = { seq = 42, generation = 7, chunkBytes = 24, maxBlockBytes = 512 }
    local blocks, meta = api.encodeCarrierBlocks(snapshot, opts)
    assertTrue(blocks, "carrier encode should succeed: " .. tostring(meta))
    assertTrue(#blocks > 1, "small chunk size should create multiple blocks")
    for index, block in ipairs(blocks) do
        assertTrue(#block <= opts.maxBlockBytes, "block " .. index .. " respects maxBlockBytes")
        assertTrue(block:match("^CS2|v=2|"), "block has protocol prefix")
        assertTrue(block:match("|crc=[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]|data=[0-9A-F]+$"),
            "block has uppercase checksum and hex payload")
        local parsed, parseReason = api.decodeCarrierBlock(block)
        assertTrue(parsed, "each block should decode: " .. tostring(parseReason))
    end

    local blocksAgain, metaAgain = api.encodeCarrierBlocks(snapshot, opts)
    assertDeepEqual(blocksAgain, blocks, "carrier encoding is deterministic")
    assertDeepEqual(metaAgain, meta, "carrier metadata is deterministic")

    local reversed = {}
    for index = #blocks, 1, -1 do reversed[#reversed + 1] = blocks[index] end
    local assembled, assembleMeta = api.assembleCarrierBlocks(reversed, NOW_MS)
    assertTrue(assembled, "out-of-order complete chunks should assemble: " .. tostring(assembleMeta))
    assertEqual(assembled.transportMode, "p2p_carrier", "receiving transport assigns provenance; payload cannot claim game-visible")
    assertEqual(assembled.sourcePlayerFingerprint, "peer-codec", "source survives carrier round-trip")
    assertEqual(assembled.inventory.weaponMods[1].accumulatedBuff, -8.75, "signed buff survives carrier round-trip")
    assertDeepEqual(assembled.inventory.weaponMods[1].enhancements, { 1, 4, 7 },
        "enhancements survive carrier round-trip")
end)

test("carrier assembly rejects partial, generation-mismatched, and oversized envelopes", function()
    local partial = baseSnapshot("peer-partial-carrier")
    partial.partial = true
    local partialBlocks = assert(api.encodeCarrierBlocks(partial, { seq = 70, generation = 7, chunkBytes = 64, maxBlockBytes = 512 }))
    local assembled, reason = api.assembleCarrierBlocks(partialBlocks, NOW_MS)
    assertNil(assembled, "partial carrier snapshot must fail")
    assertEqual(reason, "partial snapshot", "partial carrier reason")

    local generationMismatch = baseSnapshot("peer-generation-carrier")
    local mismatchBlocks = assert(api.encodeCarrierBlocks(generationMismatch, { seq = 71, generation = 8, chunkBytes = 64, maxBlockBytes = 512 }))
    assembled, reason = api.assembleCarrierBlocks(mismatchBlocks, NOW_MS)
    assertNil(assembled, "frame and snapshot generation mismatch must fail")
    assertEqual(reason, "carrier generation mismatch", "generation mismatch reason")

    local oversizedPartCount = "CS2|v=2|id=00000000-1-7|seq=1|gen=7|part=1|total=4097|crc=00000000|data="
    local parsed
    parsed, reason = api.decodeCarrierBlock(oversizedPartCount)
    assertNil(parsed, "oversized carrier part count must fail before allocation")
    assertEqual(reason, "carrier part count exceeds limit", "part bound reason")
end)

test("debug-only merges retain debug provenance", function()
    local debug = baseSnapshot("peer-debug")
    debug.transportMode = "debug_loopback"
    local merged, report = api.mergeSnapshots({ debug }, NOW_MS)
    assertTrue(merged, "debug row should merge for local diagnostics: " .. stableRepr(report))
    assertEqual(merged.transportMode, "debug_loopback", "debug evidence is never promoted to game-visible")
    assertEqual(merged.evidenceConfidence, "debug_loopback_merge", "merged confidence retains debug provenance")
end)

test("carrier assembly rejects missing, duplicate, mixed, and corrupt chunks", function()
    local snapshot = baseSnapshot("peer-corrupt")
    snapshot.inventory.relics = {
        { category = "relics", n = "DA_Relic_LongPayload", l = 3, a = -1.25, e = { 1, 4, 7, 12, 19 } },
    }
    local blocks, meta = api.encodeCarrierBlocks(snapshot, { seq = 50, generation = 7, chunkBytes = 20, maxBlockBytes = 512 })
    assertTrue(blocks and #blocks > 2, "test requires several chunks: " .. tostring(meta))

    local missing = clone(blocks)
    table.remove(missing, 2)
    local assembled, reason = api.assembleCarrierBlocks(missing, NOW_MS)
    assertNil(assembled, "missing chunk must fail")
    assertTrue(type(reason) == "string" and reason ~= "", "missing chunk provides a reason")

    local duplicate = clone(blocks)
    duplicate[#duplicate + 1] = duplicate[1]
    assembled, reason = api.assembleCarrierBlocks(duplicate, NOW_MS)
    assertNil(assembled, "duplicate chunk must fail")
    assertTrue(type(reason) == "string" and reason ~= "", "duplicate chunk provides a reason")

    local otherBlocks = assert(api.encodeCarrierBlocks(snapshot, { seq = 51, generation = 7, chunkBytes = 20, maxBlockBytes = 512 }))
    local mixed = clone(blocks)
    mixed[1] = otherBlocks[1]
    assembled, reason = api.assembleCarrierBlocks(mixed, NOW_MS)
    assertNil(assembled, "mixed message chunks must fail")
    assertTrue(type(reason) == "string" and reason ~= "", "mixed message provides a reason")

    local corrupt = clone(blocks)
    corrupt[#corrupt] = corrupt[#corrupt]:gsub("([0-9A-F])$", function(last)
        return last == "0" and "1" or "0"
    end, 1)
    assembled, reason = api.assembleCarrierBlocks(corrupt, NOW_MS)
    assertNil(assembled, "CRC corruption must fail")
    assertTrue(type(reason) == "string" and reason:lower():find("checksum", 1, true),
        "corruption reason should identify checksum failure; got " .. tostring(reason))
end)

test("carrier assembly rejects a snapshot that became stale", function()
    local snapshot = baseSnapshot("peer-stale-carrier", NOW_MS - 15001)
    local blocks, meta = api.encodeCarrierBlocks(snapshot, { seq = 60, generation = 7, chunkBytes = 64, maxBlockBytes = 512 })
    assertTrue(blocks, "encoding itself may serialize a stale snapshot for boundary testing: " .. tostring(meta))
    local assembled, reason = api.assembleCarrierBlocks(blocks, NOW_MS)
    assertNil(assembled, "assembly normalization rejects stale payload")
    assertEqual(reason, "stale snapshot", "stale carrier payload reason")
end)

io.write(string.format("1..%d\n", testsRun))
if failures > 0 then
    io.stderr:write(string.format("# %d of %d CrabSyncV2 core tests failed\n", failures, testsRun))
    os.exit(1)
end

io.write(string.format("# all %d CrabSyncV2 core tests passed\n", testsRun))
