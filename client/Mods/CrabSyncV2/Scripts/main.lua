-- CrabSyncV2 - experimental game-native/P2P convergence client
-- No Node relay, PowerShell bridge, room server, or push/recv file IPC is used.
-- RuntimeProbe evidence proves read visibility much further than write safety;
-- every deep read, carrier action, and mutation below therefore has its own gate.

local BUILD_VERSION = "2.0.0-experimental.1"
local PROTOCOL_VERSION = 2
local BYTE_MAX = 255
local UINT32_MAX = 4294967295
local ENHANCEMENT_MAX = 27
local MAX_CARRIER_BLOCK_BYTES = 8192
local MAX_CARRIER_PARTS = 4096
local MAX_CARRIER_PAYLOAD_BYTES = 1048576
local MAX_CODEC_DEPTH = 32
local MAX_CODEC_NODES = 100000
local SCRIPT_DIR = "Mods/CrabSyncV2/Scripts/"
local BACKUP_DIR = SCRIPT_DIR .. "backups/"

local CONFIG = {
    enableCrabSyncV2=false, transportMode="disabled", pollIntervalMs=1000,
    stableTicksRequired=5, maxSnapshotAgeMs=15000, maxPeers=16,
    maxInventoryItemsPerCategory=128,
    allowPeerVisibleStateRead=false, allowCarrierDiscovery=false,
    allowCarrierPublish=false, allowCarrierReceive=false,
    allowHealthRead=false, allowEquipmentRead=false, allowResourceRead=false,
    allowInventoryRead=false, allowInventoryItemTraversal=false,
    allowMetadataRead=false, allowEnhancementRead=false,
    allowDebugLoopbackTransport=false,
    healthMergePolicy="max_visible",
    equipmentMergePolicy="lowest_fingerprint",
    crystalMergePolicy="max_visible", slotMergePolicy="max_visible",
    inventoryMergePolicy="preserve_instances",
    allowApply=false, allowHealthApply=false, allowEquipmentApply=false,
    allowResourceApply=false, allowInventoryApply=false,
    allowMetadataApply=false, allowEnhancementApply=false,
    allowJoinedClientApply=false, allowMultiplayerApply=false,
    hostOnlyApply=true, dryRunApply=true, backupBeforeApply=true,
    allowOfficialFunctionApply=false, allowRawPropertyWrites=false,
    allowRawInventoryWrites=false, allowOnRepInventory=false,
    allowOnRepCrystals=false, allowClientRefreshPSUI=false,
    debugCrashBreadcrumbs=false, debugVerboseSnapshots=false,
}

local runtime = {
    lifecycleState="disabled", lifecycleGeneration=0, stableTicks=0,
    lastLifecycleSignature="", localPlayerState=nil, localRole="unknown",
    tick=0, clientInstanceId="", sessionId="", lastSnapshot=nil,
    lastMerged=nil, lastPlan=nil, lastBackupPath="", lastError="",
    lastCarrierCandidates=nil, loopbackRows={}, loopbackInjected=false,pendingRestore=nil,
    transitionActive=false, diagnosticCounts={},
}

local function nowMs()
    return math.floor((os.time() or 0) * 1000)
end

local function isFinite(value)
    local n = tonumber(value)
    return n ~= nil and n == n and n ~= math.huge and n ~= -math.huge
end

local function clampInteger(value, low, high)
    if not isFinite(value) then return low end
    local n = math.floor(tonumber(value))
    if n < low then return low end
    if n > high then return high end
    return n
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function hasKey(t, key)
    return type(t) == "table" and rawget(t, key) ~= nil
end

local function copyArray(values)
    local out = {}
    if type(values) == "table" then
        for _, value in ipairs(values) do out[#out + 1] = value end
    end
    return out
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local out = {}
    for key, child in pairs(value) do out[deepCopy(key, seen)] = deepCopy(child, seen) end
    seen[value] = nil
    return out
end

local function sortedUniqueStrings(values)
    local out, seen = {}, {}
    for _, value in ipairs(type(values) == "table" and values or {}) do
        local text = tostring(value or "")
        if text ~= "" and not seen[text] then seen[text] = true; out[#out + 1] = text end
    end
    table.sort(out)
    return out
end

local function fingerprintValue(value)
    -- RuntimeProbe-compatible non-cryptographic fingerprint. Raw identity values
    -- are consumed only inside this function and are never printed or serialized.
    local text = tostring(value or "")
    if text == "" then return "", 0 end
    local hash = 2166136261
    for i = 1, #text do
        hash = (hash * 16777619 + string.byte(text, i)) % 4294967296
    end
    return string.format("%08x", hash), #text
end

local function formatNumber(value)
    local n = tonumber(value) or 0
    if not isFinite(n) then n = 0 end
    return string.format("%.17g", n):gsub(",", ".")
end

local function log(scope, message)
    print(string.format("[CrabSyncV2:%s] %s\n", tostring(scope), tostring(message)))
end

local function breadcrumb(phase, state)
    if CONFIG.debugCrashBreadcrumbs then
        log("breadcrumb", tostring(phase) .. " " .. tostring(state or ""))
    end
end

local function addUnsupported(container, field, reason)
    if type(container) ~= "table" then return end
    container.unsupportedFields = container.unsupportedFields or {}
    container.unsupportedFields[#container.unsupportedFields + 1] =
        tostring(field) .. ":" .. tostring(reason or "unsupported")
end

-- --------------------------------------------------------------------------
-- Pure snapshot normalization
-- --------------------------------------------------------------------------

local INVENTORY_CATEGORIES = {
    {key="weaponMods", property="WeaponMods", daField="WeaponModDA", daClass="CrabWeaponModDA"},
    {key="abilityMods", property="AbilityMods", daField="AbilityModDA", daClass="CrabAbilityModDA"},
    {key="meleeMods", property="MeleeMods", daField="MeleeModDA", daClass="CrabMeleeModDA"},
    {key="perks", property="Perks", daField="PerkDA", daClass="CrabPerkDA"},
    {key="relics", property="Relics", daField="RelicDA", daClass="CrabRelicDA"},
}

local function normalizeEnhancements(values)
    if type(values) ~= "table" then return nil end
    local count,maxIndex=0,0
    for key,value in pairs(values) do
        if type(key)~="number" or key<1 or key~=math.floor(key) then return nil end
        if not isFinite(value) or tonumber(value)~=math.floor(tonumber(value))
            or tonumber(value)<0 or tonumber(value)>ENHANCEMENT_MAX then return nil end
        count=count+1;if key>maxIndex then maxIndex=key end
    end
    if count>BYTE_MAX then return nil end
    if count~=maxIndex then return nil end
    local out = {}
    for index=1,maxIndex do out[index]=tonumber(values[index]) end
    return out
end

local function normalizeItem(raw, category, snapshot, preserveItemProvenance)
    raw = type(raw) == "table" and raw or {}
    local levelPresent = hasKey(raw, "level") or hasKey(raw, "l")
    local accumPresent = hasKey(raw, "accumulatedBuff") or hasKey(raw, "accum") or hasKey(raw, "a")
    local enhancementsPresent = hasKey(raw, "enhancements") or hasKey(raw, "e")
    local levelKnown = raw.levelKnown == true or (raw.levelKnown ~= false and levelPresent)
    local accumKnown = raw.accumulatedBuffKnown == true or raw.accumKnown == true
        or ((raw.accumulatedBuffKnown ~= false and raw.accumKnown ~= false) and accumPresent)
    local enhancementsKnown = raw.enhancementsKnown == true
        or (raw.enhancementsKnown ~= false and enhancementsPresent)
    local levelValue = raw.level
    if levelValue == nil then levelValue = raw.l end
    local accumValue = raw.accumulatedBuff
    if accumValue == nil then accumValue = raw.accum end
    if accumValue == nil then accumValue = raw.a end
    local enhancementValue = raw.enhancements
    if enhancementValue == nil then enhancementValue = raw.e end

    if not isFinite(levelValue) then levelKnown = false; levelValue = nil end
    if not isFinite(accumValue) then accumKnown = false; accumValue = nil end
    local normalizedEnhancements = normalizeEnhancements(enhancementValue)
    local invalidEnhancements=enhancementsKnown and normalizedEnhancements==nil
    if invalidEnhancements then enhancementsKnown = false end

    local knownCount = (levelKnown and 1 or 0) + (accumKnown and 1 or 0) + (enhancementsKnown and 1 or 0)
    local metadataStatus
    if knownCount == 3 then metadataStatus = "ok"
    elseif knownCount > 0 then metadataStatus = "partial"
    else metadataStatus = "unsupported" end

    local item = {
        category=tostring(category or ""),
        sourcePlayer=tostring((preserveItemProvenance and raw.sourcePlayer) or (snapshot and snapshot.sourcePlayerFingerprint) or ""),
        visibilityClass=tostring((preserveItemProvenance and raw.visibilityClass) or (snapshot and snapshot.visibilityClass) or "unresolved"),
        lifecycleGeneration=clampInteger((preserveItemProvenance and raw.lifecycleGeneration) or (snapshot and snapshot.lifecycleGeneration), 0, UINT32_MAX),
        index=(isFinite(raw.index or raw.i) and clampInteger(raw.index or raw.i, 0, UINT32_MAX) or nil),
        daShortName=tostring(raw.daShortName or raw.shortName or raw.name or raw.n or ""),
        daFullName=tostring(raw.daFullName or raw.fullName or raw.fullDA or raw.d or ""),
        level=levelKnown and clampInteger(levelValue, 1, BYTE_MAX) or nil,
        levelKnown=levelKnown,
        accumulatedBuff=accumKnown and tonumber(accumValue) or nil,
        accumulatedBuffKnown=accumKnown,
        enhancements=enhancementsKnown and normalizedEnhancements or nil,
        enhancementsKnown=enhancementsKnown,
        metadataStatus=metadataStatus,
        unsupportedFields=sortedUniqueStrings(raw.unsupportedFields),
    }
    if item.daShortName == "" and item.daFullName == "" then
        item.unsupportedFields[#item.unsupportedFields + 1] = "DataAsset:identity unavailable"
    end
    if invalidEnhancements then item.unsupportedFields[#item.unsupportedFields+1]="InventoryInfo.Enhancements:invalid, sparse, or out-of-enum sequence" end
    item.unsupportedFields = sortedUniqueStrings(item.unsupportedFields)
    return item
end

local function normalizeDA(raw)
    if type(raw) == "string" then raw = {shortName=raw} end
    raw = type(raw) == "table" and raw or {}
    local shortName = tostring(raw.shortName or raw.daShortName or raw.name or raw.n or "")
    local fullName = tostring(raw.fullName or raw.daFullName or raw.path or raw.d or "")
    return {supported=(raw.supported == true or shortName ~= "" or fullName ~= ""), shortName=shortName, fullName=fullName}
end

local function normalizeSnapshot(raw, suppliedNowMs, options)
    if type(raw) ~= "table" then return nil, "snapshot must be a table" end
    options=type(options)=="table" and options or {}
    local protocolValue=raw.protocolVersion or raw.protocol or raw.v
    if protocolValue==nil then return nil,"missing protocol" end
    if not isFinite(protocolValue) or tonumber(protocolValue)~=math.floor(tonumber(protocolValue)) then return nil,"invalid protocol" end
    local protocol = clampInteger(protocolValue, 0, BYTE_MAX)
    if protocol ~= PROTOCOL_VERSION then return nil, "wrong protocol" end
    local timestamp = raw.timestampMs or raw.timestamp
    if timestamp==nil then return nil,"missing timestamp" end
    if not isFinite(timestamp) then return nil, "invalid timestamp" end
    timestamp = math.max(0, math.floor(tonumber(timestamp)))
    local generationValue=raw.lifecycleGeneration
    if generationValue==nil then generationValue=raw.generation end
    if generationValue==nil then return nil,"missing lifecycle generation" end
    if not isFinite(generationValue) or tonumber(generationValue)~=math.floor(tonumber(generationValue)) or tonumber(generationValue)<0 or tonumber(generationValue)>UINT32_MAX then return nil,"invalid lifecycle generation" end
    local current=tonumber(suppliedNowMs)
    if current and current>0 then
        if timestamp>current+5000 then return nil,"future timestamp" end
        if current-timestamp>CONFIG.maxSnapshotAgeMs then return nil,"stale snapshot" end
    end

    local out = {
        protocolVersion=PROTOCOL_VERSION,
        sessionId=tostring(raw.sessionId or raw.session or ""),
        clientInstanceId=tostring(raw.clientInstanceId or raw.instanceId or ""),
        sourcePlayerFingerprint=tostring(raw.sourcePlayerFingerprint or raw.sourcePlayer or raw.playerFingerprint or ""),
        sourceRole=tostring(raw.sourceRole or raw.role or "unknown"),
        lifecycleGeneration=clampInteger(generationValue, 0, UINT32_MAX),
        timestampMs=timestamp,
        tick=clampInteger(raw.tick, 0, UINT32_MAX),
        visibilityClass=tostring(raw.visibilityClass or "unresolved"),
        evidenceConfidence=tostring(raw.evidenceConfidence or "unresolved"),
        transportMode=tostring(raw.transportMode or raw.transport or "disabled"),
        partial=(raw.partial == true),
        unsupportedFields=sortedUniqueStrings(raw.unsupportedFields),
        carrier=type(raw.carrier) == "table" and deepCopy(raw.carrier) or {},
    }
    if not ({disabled=true,game_visible=true,p2p_carrier=true,debug_loopback=true})[out.transportMode] then out.transportMode="disabled" end

    local health = type(raw.health) == "table" and raw.health or {}
    local function finiteOrNil(value) return isFinite(value) and tonumber(value) or nil end
    local rawArmor=type(health.armor)=="table" and health.armor or {}
    local armor={
        currentPlates=finiteOrNil(rawArmor.currentPlates),
        currentPlateHealth=finiteOrNil(rawArmor.currentPlateHealth),
        previousPlateHealth=finiteOrNil(rawArmor.previousPlateHealth),
    }
    local armorObserved=health.armorObserved==true or armor.currentPlates~=nil or armor.currentPlateHealth~=nil or armor.previousPlateHealth~=nil
    out.health = {
        supported=(health.supported == true),
        currentHealth=finiteOrNil(health.currentHealth or health.current),
        currentMaxHealth=finiteOrNil(health.currentMaxHealth or health.max),
        baseMaxHealth=finiteOrNil(health.baseMaxHealth or health.baseMax),
        maxHealthMultiplier=finiteOrNil(health.maxHealthMultiplier or health.multiplier),
        previousHealth=finiteOrNil(health.previousHealth),
        previousMaxHealth=finiteOrNil(health.previousMaxHealth),
        armorSupported=(health.armorSupported == true),
        armorObserved=armorObserved,armor=armor,
        armorObservations=type(health.armorObservations)=="table" and deepCopy(health.armorObservations) or {},
        unsupportedFields=sortedUniqueStrings(health.unsupportedFields),
    }
    if out.health.currentHealth ~= nil or out.health.currentMaxHealth ~= nil then out.health.supported = true end

    local equipment = type(raw.equipment) == "table" and raw.equipment or {}
    out.equipment = {
        supported=(equipment.supported == true),
        weapon=normalizeDA(equipment.weapon), ability=normalizeDA(equipment.ability),
        melee=normalizeDA(equipment.melee),
        unsupportedFields=sortedUniqueStrings(equipment.unsupportedFields),
    }
    if out.equipment.weapon.supported or out.equipment.ability.supported or out.equipment.melee.supported then
        out.equipment.supported = true
    end

    local resources = type(raw.resources) == "table" and raw.resources or {}
    local slots = type(resources.slots) == "table" and resources.slots or {}
    local crystals = nil
    if isFinite(resources.crystals) then crystals = clampInteger(resources.crystals, 0, UINT32_MAX) end
    out.resources = {
        supported=(resources.supported == true or crystals ~= nil), crystals=crystals,
        slots={
            weaponMods=isFinite(slots.weaponMods) and clampInteger(slots.weaponMods, 0, BYTE_MAX) or nil,
            abilityMods=isFinite(slots.abilityMods) and clampInteger(slots.abilityMods, 0, BYTE_MAX) or nil,
            meleeMods=isFinite(slots.meleeMods) and clampInteger(slots.meleeMods, 0, BYTE_MAX) or nil,
            perks=isFinite(slots.perks) and clampInteger(slots.perks, 0, BYTE_MAX) or nil,
        },
        keysSupported=false,
        unsupportedFields=sortedUniqueStrings(resources.unsupportedFields),
    }
    for _, value in pairs(out.resources.slots) do if value ~= nil then out.resources.supported = true end end

    local inventory = type(raw.inventory) == "table" and raw.inventory or {}
    local rawCategorySupported=type(inventory.categorySupported)=="table" and inventory.categorySupported or nil
    local rawCounts=type(inventory.counts)=="table" and inventory.counts or {}
    out.inventory = {supported=false,counts={},categorySupported={},unsupportedFields=sortedUniqueStrings(inventory.unsupportedFields)}
    for _, category in ipairs(INVENTORY_CATEGORIES) do
        local fieldPresent=hasKey(inventory,category.key) and type(inventory[category.key])=="table"
        local rawItems=fieldPresent and inventory[category.key] or {}
        if #rawItems>CONFIG.maxInventoryItemsPerCategory then return nil,"inventory category exceeds item limit: "..category.key end
        out.inventory[category.key] = {}
        for _, item in ipairs(rawItems) do
            out.inventory[category.key][#out.inventory[category.key] + 1] = normalizeItem(item, category.key, out, options.preserveItemProvenance==true)
        end
        local countPresent=hasKey(rawCounts,category.key)
        local countValid=not countPresent or (isFinite(rawCounts[category.key]) and clampInteger(rawCounts[category.key],0,UINT32_MAX)==#rawItems)
        local categorySupported=rawCategorySupported~=nil and rawCategorySupported[category.key]==true and fieldPresent and countValid
        out.inventory.categorySupported[category.key]=categorySupported
        if categorySupported then out.inventory.counts[category.key]=#rawItems
        elseif rawCategorySupported and rawCategorySupported[category.key]==true then out.inventory.unsupportedFields[#out.inventory.unsupportedFields+1]=category.key..":category completeness proof missing or inconsistent" end
        if categorySupported then out.inventory.supported=true end
    end
    return out
end

local function itemIdentity(item)
    local fullName = tostring(item.daFullName or "")
    if fullName ~= "" then return fullName end
    return tostring(item.daShortName or "")
end

local function itemSignature(item)
    local enhancements = "?"
    if item.enhancementsKnown then
        local parts = {}; for _, value in ipairs(item.enhancements or {}) do parts[#parts + 1] = tostring(value) end
        enhancements = table.concat(parts, ",")
    end
    return table.concat({
        tostring(item.sourcePlayer or ""), tostring(item.category or ""), itemIdentity(item),
        item.levelKnown and tostring(item.level) or "?",
        item.accumulatedBuffKnown and formatNumber(item.accumulatedBuff) or "?",
        enhancements, item.index ~= nil and tostring(item.index) or "?",
    }, "|")
end

local function exactMetadataSignature(item, includeSource)
    local enhancements = "?"
    if item.enhancementsKnown then
        local parts={};for _,value in ipairs(item.enhancements or {}) do parts[#parts+1]=tostring(value) end
        enhancements=table.concat(parts,",")
    end
    return table.concat({
        includeSource and tostring(item.sourcePlayer or "") or "shared",
        tostring(item.category or ""),itemIdentity(item),
        item.levelKnown and tostring(item.level) or "?",
        item.accumulatedBuffKnown and formatNumber(item.accumulatedBuff) or "?",
        enhancements,
    },"|")
end

-- --------------------------------------------------------------------------
-- Deterministic typed codec and CrabSyncBlock chunk framing (pure)
-- --------------------------------------------------------------------------

local function codecEncode(value)
    local seen,nodeCount = {},0
    local function encode(v,depth)
        depth=depth or 0
        if depth>MAX_CODEC_DEPTH then error("codec depth limit exceeded") end
        nodeCount=nodeCount+1;if nodeCount>MAX_CODEC_NODES then error("codec node limit exceeded") end
        local kind = type(v)
        if kind == "nil" then return "Z" end
        if kind == "boolean" then return v and "T" or "F" end
        if kind == "number" then local s=formatNumber(v); return "D" .. #s .. ":" .. s end
        if kind == "string" then return "S" .. #v .. ":" .. v end
        if kind ~= "table" then error("unsupported codec type: " .. kind) end
        if seen[v] then error("cyclic table") end
        seen[v] = true
        local count, maxIndex, array = 0, 0, true
        for key, _ in pairs(v) do
            count = count + 1
            if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then array=false
            else if key > maxIndex then maxIndex=key end end
        end
        if array and maxIndex == count then
            local parts = {"A", tostring(count), ":"}
            for i=1,count do parts[#parts+1]=encode(v[i],depth+1) end
            seen[v]=nil; return table.concat(parts)
        end
        local keys = {}
        for key,_ in pairs(v) do
            if type(key) ~= "string" then error("object codec keys must be strings") end
            keys[#keys+1]=key
        end
        table.sort(keys)
        local parts = {"O", tostring(#keys), ":"}
        for _,key in ipairs(keys) do parts[#parts+1]=encode(key,depth+1); parts[#parts+1]=encode(v[key],depth+1) end
        seen[v]=nil; return table.concat(parts)
    end
    local ok, result = pcall(encode, value)
    if not ok then return nil, tostring(result) end
    return result
end

local function codecDecode(blob)
    if type(blob) ~= "string" then return nil, "codec input must be a string" end
    if #blob>MAX_CARRIER_PAYLOAD_BYTES then return nil,"codec payload exceeds limit" end
    local position = 1
    local nodeCount=0
    local function readCount()
        local colon = blob:find(":", position, true)
        if not colon then error("missing length delimiter") end
        local raw = blob:sub(position, colon - 1)
        if not raw:match("^%d+$") then error("invalid length") end
        position = colon + 1
        return tonumber(raw)
    end
    local function decode(depth)
        depth=depth or 0
        if depth>MAX_CODEC_DEPTH then error("codec depth limit exceeded") end
        nodeCount=nodeCount+1;if nodeCount>MAX_CODEC_NODES then error("codec node limit exceeded") end
        local tag = blob:sub(position, position); position = position + 1
        if tag == "Z" then return nil end
        if tag == "T" then return true end
        if tag == "F" then return false end
        if tag == "S" or tag == "D" then
            local length = readCount()
            local last = position + length - 1
            if last > #blob then error("truncated scalar") end
            local raw = blob:sub(position, last); position = last + 1
            if tag == "S" then return raw end
            local number = tonumber(raw); if not isFinite(number) then error("invalid number") end
            return number
        end
        if tag == "A" then
            local count = readCount(); local out = {}
            if count>MAX_CODEC_NODES then error("array item limit exceeded") end
            for i=1,count do out[i]=decode(depth+1) end
            return out
        end
        if tag == "O" then
            local count = readCount(); local out = {}
            if count>MAX_CODEC_NODES then error("object item limit exceeded") end
            for _=1,count do
                local key=decode(depth+1); if type(key)~="string" then error("invalid object key") end
                out[key]=decode(depth+1)
            end
            return out
        end
        error("unknown codec tag")
    end
    local ok, value = pcall(decode)
    if not ok then return nil, tostring(value) end
    if position ~= #blob + 1 then return nil, "trailing codec data" end
    return value
end

local function adler32(text)
    local a, b = 1, 0
    for i=1,#text do a=(a+string.byte(text,i))%65521; b=(b+a)%65521 end
    return string.format("%08X", b*65536+a)
end

local function toHex(text)
    return (text:gsub(".", function(char) return string.format("%02X", string.byte(char)) end))
end

local function fromHex(hex)
    if type(hex)~="string" or #hex%2~=0 or not hex:match("^[0-9A-F]*$") then return nil,"invalid hex payload" end
    return (hex:gsub("%x%x", function(pair) return string.char(tonumber(pair,16)) end))
end

local function encodeSnapshot(snapshot)
    local normalized, reason = normalizeSnapshot(snapshot, snapshot and snapshot.timestampMs or 0)
    if not normalized then return nil, reason end
    return codecEncode(normalized)
end

local function decodeSnapshot(blob)
    local decoded, reason = codecDecode(blob)
    if not decoded then return nil, reason end
    return normalizeSnapshot(decoded, decoded.timestampMs or 0)
end

local function encodeCarrierBlocks(snapshot, options)
    options = type(options)=="table" and options or {}
    local normalized, reason = normalizeSnapshot(snapshot, snapshot and snapshot.timestampMs or 0)
    if not normalized then return nil, reason end
    local blob, encodeReason = codecEncode(normalized)
    if not blob then return nil, encodeReason end
    if #blob>MAX_CARRIER_PAYLOAD_BYTES then return nil,"carrier payload exceeds limit" end
    local hex, crc = toHex(blob), adler32(blob)
    local chunkBytes = clampInteger(options.chunkBytes or 96, 8, 4000)
    local chunkChars = chunkBytes * 2
    local total = math.max(1, math.ceil(#hex/chunkChars))
    if total>MAX_CARRIER_PARTS then return nil,"carrier part count exceeds limit" end
    local seq = clampInteger(options.seq or normalized.tick, 0, UINT32_MAX)
    local generation = clampInteger(options.generation or normalized.lifecycleGeneration, 0, UINT32_MAX)
    local blockId = crc .. "-" .. tostring(seq) .. "-" .. tostring(generation)
    local blocks = {}
    for part=1,total do
        local data = hex:sub((part-1)*chunkChars+1, part*chunkChars)
        local block = string.format("CS2|v=%d|id=%s|seq=%d|gen=%d|part=%d|total=%d|crc=%s|data=%s",
            PROTOCOL_VERSION, blockId, seq, generation, part, total, crc, data)
        local requestedMax=options.maxBlockBytes and tonumber(options.maxBlockBytes) or MAX_CARRIER_BLOCK_BYTES
        local effectiveMax=math.min(MAX_CARRIER_BLOCK_BYTES,requestedMax or MAX_CARRIER_BLOCK_BYTES)
        if #block > effectiveMax then
            return nil, "block exceeds maxBlockBytes"
        end
        blocks[#blocks+1]=block
    end
    return blocks, {blockId=blockId,crc=crc,parts=total,encodedBytes=#blob,chunkBytes=chunkBytes}
end

local function decodeCarrierBlock(block)
    if type(block)~="string" then return nil,"carrier block must be a string" end
    if #block>MAX_CARRIER_BLOCK_BYTES then return nil,"carrier block exceeds limit" end
    local version,id,seq,generation,part,total,crc,data = block:match(
        "^CS2|v=(%d+)|id=([%w_%-]+)|seq=(%d+)|gen=(%d+)|part=(%d+)|total=(%d+)|crc=([0-9A-F]+)|data=([0-9A-F]*)$")
    if not version then return nil,"malformed carrier block" end
    version,seq,generation,part,total=tonumber(version),tonumber(seq),tonumber(generation),tonumber(part),tonumber(total)
    if version~=PROTOCOL_VERSION then return nil,"wrong protocol" end
    if not isFinite(seq) or seq<0 or seq>UINT32_MAX or seq~=math.floor(seq) then return nil,"invalid sequence" end
    if not isFinite(generation) or generation<0 or generation>UINT32_MAX or generation~=math.floor(generation) then return nil,"invalid generation" end
    if not isFinite(part) or not isFinite(total) or part~=math.floor(part) or total~=math.floor(total) then return nil,"invalid part range" end
    if total>MAX_CARRIER_PARTS then return nil,"carrier part count exceeds limit" end
    if #crc~=8 then return nil,"invalid checksum field" end
    if total<1 or part<1 or part>total then return nil,"invalid part range" end
    if #data%2~=0 then return nil,"invalid hex payload" end
    if #id>96 or id~=(crc.."-"..tostring(seq).."-"..tostring(generation)) then return nil,"invalid block id" end
    return {protocolVersion=version,blockId=id,seq=seq,generation=generation,part=part,total=total,crc=crc,dataHex=data}
end

local function assembleCarrierBlocks(blocks, suppliedNowMs)
    if type(blocks)~="table" or #blocks==0 then return nil,"no carrier blocks" end
    if #blocks>MAX_CARRIER_PARTS then return nil,"carrier part count exceeds limit" end
    local parsed, first = {}, nil
    for _,block in ipairs(blocks) do
        local row,reason=decodeCarrierBlock(block); if not row then return nil,reason end
        if not first then first=row
        elseif row.blockId~=first.blockId or row.total~=first.total or row.crc~=first.crc
            or row.seq~=first.seq or row.generation~=first.generation then return nil,"mixed carrier block set" end
        if parsed[row.part] then return nil,"duplicate carrier part" end
        parsed[row.part]=row
    end
    if #blocks~=first.total then return nil,"missing carrier part" end
    local hexParts,totalHexChars={},0; for i=1,first.total do if not parsed[i] then return nil,"missing carrier part" end;totalHexChars=totalHexChars+#parsed[i].dataHex;if totalHexChars>MAX_CARRIER_PAYLOAD_BYTES*2 then return nil,"carrier payload exceeds limit" end;hexParts[#hexParts+1]=parsed[i].dataHex end
    local blob,hexReason=fromHex(table.concat(hexParts)); if not blob then return nil,hexReason end
    if adler32(blob)~=first.crc then return nil,"crc checksum mismatch" end
    local decoded,decodeReason=codecDecode(blob); if not decoded then return nil,decodeReason end
    local normalized,normalizeReason=normalizeSnapshot(decoded,suppliedNowMs); if not normalized then return nil,normalizeReason end
    if normalized.partial then return nil,"partial snapshot" end
    if normalized.lifecycleGeneration~=first.generation then return nil,"carrier generation mismatch" end
    normalized.transportMode="p2p_carrier"
    normalized.carrier={blockId=first.blockId,seq=first.seq,generation=first.generation,crc=first.crc,parts=first.total}
    local current=tonumber(suppliedNowMs)
    if current then
        if normalized.timestampMs>current+5000 then return nil,"future timestamp" end
        if current-normalized.timestampMs>CONFIG.maxSnapshotAgeMs then return nil,"stale snapshot" end
    end
    return normalized,{blockId=first.blockId,seq=first.seq,generation=first.generation,crc=first.crc,parts=first.total}
end

-- --------------------------------------------------------------------------
-- Deterministic merge (pure)
-- --------------------------------------------------------------------------

local function mergeSnapshots(rows, suppliedNowMs, expectedSessionId, expectedGeneration)
    local current=tonumber(suppliedNowMs) or 0
    local report={accepted=0,rejected={},policies={
        health=CONFIG.healthMergePolicy,equipment=CONFIG.equipmentMergePolicy,
        crystals=CONFIG.crystalMergePolicy,slots=CONFIG.slotMergePolicy,
        inventory=CONFIG.inventoryMergePolicy,
    }}
    local priority={game_visible=4,p2p_carrier=3,debug_loopback=2,disabled=1}
    local bySource={}
    for index,raw in ipairs(type(rows)=="table" and rows or {}) do
        local snapshot,reason=normalizeSnapshot(raw,current)
        if not snapshot then report.rejected[#report.rejected+1]={index=index,reason=reason}
        elseif snapshot.sourcePlayerFingerprint=="" then report.rejected[#report.rejected+1]={index=index,reason="missing source fingerprint"}
        elseif expectedSessionId and expectedSessionId~="" and snapshot.sessionId=="" then report.rejected[#report.rejected+1]={index=index,reason="missing session fingerprint"}
        elseif expectedSessionId and expectedSessionId~="" and snapshot.sessionId~=expectedSessionId then report.rejected[#report.rejected+1]={index=index,reason="session mismatch"}
        elseif expectedGeneration~=nil and snapshot.lifecycleGeneration~=expectedGeneration then report.rejected[#report.rejected+1]={index=index,reason="lifecycle generation mismatch"}
        elseif snapshot.partial then report.rejected[#report.rejected+1]={index=index,reason="partial snapshot"}
        elseif current>0 and snapshot.timestampMs>current+5000 then report.rejected[#report.rejected+1]={index=index,reason="future timestamp"}
        elseif current>0 and current-snapshot.timestampMs>CONFIG.maxSnapshotAgeMs then report.rejected[#report.rejected+1]={index=index,reason="stale snapshot"}
        else
            local prior=bySource[snapshot.sourcePlayerFingerprint]
            local replace=not prior
            if prior then
                local newP,oldP=priority[snapshot.transportMode] or 0,priority[prior.transportMode] or 0
                if newP~=oldP then replace=newP>oldP
                elseif snapshot.lifecycleGeneration~=prior.lifecycleGeneration then replace=snapshot.lifecycleGeneration>prior.lifecycleGeneration
                elseif snapshot.timestampMs~=prior.timestampMs then replace=snapshot.timestampMs>prior.timestampMs
                else
                    local a=codecEncode(snapshot) or ""; local b=codecEncode(prior) or ""; replace=a<b
                end
            end
            if replace then bySource[snapshot.sourcePlayerFingerprint]=snapshot end
        end
    end
    local accepted={}; for _,snapshot in pairs(bySource) do accepted[#accepted+1]=snapshot end
    table.sort(accepted,function(a,b) return a.sourcePlayerFingerprint<b.sourcePlayerFingerprint end)
    report.accepted=#accepted
    if #accepted==0 then report.reason="no usable snapshots";return nil,report end

    local mergedTransport="game_visible"
    local mergedPriority=priority[mergedTransport]
    for _,snapshot in ipairs(accepted) do
        local candidatePriority=priority[snapshot.transportMode] or 0
        if candidatePriority<mergedPriority then mergedPriority=candidatePriority;mergedTransport=snapshot.transportMode end
    end
    local merged={
        protocolVersion=PROTOCOL_VERSION,sessionId=accepted[1].sessionId,clientInstanceId="merged",
        sourcePlayerFingerprint="merged",sourceRole="converged",
        lifecycleGeneration=0,timestampMs=current,tick=0,visibilityClass="converged",
        evidenceConfidence=(mergedTransport=="game_visible" and "runtime_visible_merge" or mergedTransport.."_merge"),transportMode=mergedTransport,partial=false,
        unsupportedFields={},carrier={},
        health={supported=false,unsupportedFields={}},
        equipment={supported=false,weapon=normalizeDA(nil),ability=normalizeDA(nil),melee=normalizeDA(nil),unsupportedFields={}},
        resources={supported=false,crystals=nil,slots={weaponMods=nil,abilityMods=nil,meleeMods=nil,perks=nil},keysSupported=false,unsupportedFields={}},
        inventory={supported=false,counts={},categorySupported={},weaponMods={},abilityMods={},meleeMods={},perks={},relics={},unsupportedFields={}},
    }
    for _,snapshot in ipairs(accepted) do
        merged.lifecycleGeneration=math.max(merged.lifecycleGeneration,snapshot.lifecycleGeneration)
        merged.tick=math.max(merged.tick,snapshot.tick)
        for _,field in ipairs(snapshot.unsupportedFields) do merged.unsupportedFields[#merged.unsupportedFields+1]=snapshot.sourcePlayerFingerprint..":"..field end
    end

    local healthRows={}; for _,s in ipairs(accepted) do if s.health.supported and s.health.currentHealth~=nil and s.health.currentMaxHealth~=nil then healthRows[#healthRows+1]=s end end
    if #healthRows>0 then
        local h={supported=true,currentHealth=nil,currentMaxHealth=nil,baseMaxHealth=nil,maxHealthMultiplier=nil,armorSupported=false,armorObserved=false,armor={},armorObservations={},unsupportedFields={}}
        if CONFIG.healthMergePolicy=="sum_visible" then
            h.currentHealth=0;h.currentMaxHealth=0
            for _,s in ipairs(healthRows) do
                h.currentHealth=h.currentHealth+s.health.currentHealth;h.currentMaxHealth=h.currentMaxHealth+s.health.currentMaxHealth
                if s.health.baseMaxHealth~=nil then h.baseMaxHealth=(h.baseMaxHealth or 0)+s.health.baseMaxHealth end
                if s.health.maxHealthMultiplier~=nil then h.maxHealthMultiplier=h.maxHealthMultiplier and math.max(h.maxHealthMultiplier,s.health.maxHealthMultiplier) or s.health.maxHealthMultiplier end
            end
        else
            for _,s in ipairs(healthRows) do
                h.currentHealth=h.currentHealth and math.max(h.currentHealth,s.health.currentHealth) or s.health.currentHealth
                h.currentMaxHealth=h.currentMaxHealth and math.max(h.currentMaxHealth,s.health.currentMaxHealth) or s.health.currentMaxHealth
                if s.health.baseMaxHealth~=nil then h.baseMaxHealth=h.baseMaxHealth and math.max(h.baseMaxHealth,s.health.baseMaxHealth) or s.health.baseMaxHealth end
                if s.health.maxHealthMultiplier~=nil then h.maxHealthMultiplier=h.maxHealthMultiplier and math.max(h.maxHealthMultiplier,s.health.maxHealthMultiplier) or s.health.maxHealthMultiplier end
            end
        end
        for _,s in ipairs(healthRows) do if s.health.armorObserved then h.armorObserved=true;h.armorObservations[#h.armorObservations+1]={sourcePlayerFingerprint=s.sourcePlayerFingerprint,armor=deepCopy(s.health.armor)} end end
        if h.baseMaxHealth==nil then addUnsupported(h,"BaseMaxHealth","no visible observation") end
        if h.maxHealthMultiplier==nil then addUnsupported(h,"MaxHealthMultiplier","no visible observation") end
        addUnsupported(h,"armor","policy unresolved; observations retained but not converged")
        merged.health=h
    else addUnsupported(merged.health,"health","no complete visible rows") end

    -- All observers can sort the same fingerprint rows. A local-only "host" label
    -- is not used for authority because joined clients may label that row unknown.
    for _,key in ipairs({"weapon","ability","melee"}) do
        local selected=nil
        for _,s in ipairs(accepted) do if s.equipment[key] and s.equipment[key].supported then selected=s.equipment[key];break end end
        if selected then merged.equipment[key]=deepCopy(selected);merged.equipment.supported=true
        else addUnsupported(merged.equipment,key,"no visible row") end
    end

    local crystalValues={}; local slotValues={weaponMods={},abilityMods={},meleeMods={},perks={}}
    for _,s in ipairs(accepted) do
        if s.resources.crystals~=nil then crystalValues[#crystalValues+1]=s.resources.crystals end
        for key,_ in pairs(slotValues) do local v=s.resources.slots[key];if v~=nil then slotValues[key][#slotValues[key]+1]=v end end
    end
    if #crystalValues>0 then
        local value=0;for _,v in ipairs(crystalValues) do if CONFIG.crystalMergePolicy=="sum_visible" then value=math.min(UINT32_MAX,value+v) else value=math.max(value,v) end end
        merged.resources.crystals=value;merged.resources.supported=true
    else addUnsupported(merged.resources,"Crystals","no visible rows") end
    for key,values in pairs(slotValues) do
        if #values>0 then local value=0;for _,v in ipairs(values) do if CONFIG.slotMergePolicy=="sum_visible" then value=math.min(BYTE_MAX,value+v) else value=math.max(value,v) end end;merged.resources.slots[key]=value;merged.resources.supported=true
        else addUnsupported(merged.resources,"slots."..key,"no visible rows") end
    end

    if CONFIG.inventoryMergePolicy=="preserve_instances" then
        -- Preserve every observed source instance. Cross-source exact duplicates
        -- are intentionally not collapsed because no stable origin/contribution
        -- ledger exists. Multiplayer inventory apply remains blocked so this
        -- diagnostic union cannot feed back and multiply on the next observation.
        for _,category in ipairs(INVENTORY_CATEGORIES) do
            local categoryObserved=false
            for _,s in ipairs(accepted) do
                if s.inventory.categorySupported and s.inventory.categorySupported[category.key] then
                    categoryObserved=true
                    merged.inventory.supported=true
                    for _,item in ipairs(s.inventory[category.key]) do
                        local complete=item.levelKnown and item.accumulatedBuffKnown and item.enhancementsKnown
                        merged.inventory[category.key][#merged.inventory[category.key]+1]=deepCopy(item)
                        if not complete then merged.inventory.unsupportedFields[#merged.inventory.unsupportedFields+1]=s.sourcePlayerFingerprint..":"..category.key..":unknown metadata prevents cross-peer dedupe/apply" end
                    end
                else merged.inventory.unsupportedFields[#merged.inventory.unsupportedFields+1]=s.sourcePlayerFingerprint..":"..category.key..":inventory category unavailable or partial" end
            end
            merged.inventory.categorySupported[category.key]=categoryObserved
            if categoryObserved then merged.inventory.counts[category.key]=#merged.inventory[category.key] end
            table.sort(merged.inventory[category.key],function(a,b) return itemSignature(a)<itemSignature(b) end)
        end
        if #accepted>1 and merged.inventory.supported then merged.inventory.unsupportedFields[#merged.inventory.unsupportedFields+1]="multiplayer inventory provenance ledger unavailable; apply blocked" end
    else
        merged.inventory=deepCopy(accepted[1].inventory)
    end
    merged.unsupportedFields=sortedUniqueStrings(merged.unsupportedFields)
    merged.health.unsupportedFields=sortedUniqueStrings(merged.health.unsupportedFields)
    merged.equipment.unsupportedFields=sortedUniqueStrings(merged.equipment.unsupportedFields)
    merged.resources.unsupportedFields=sortedUniqueStrings(merged.resources.unsupportedFields)
    merged.inventory.unsupportedFields=sortedUniqueStrings(merged.inventory.unsupportedFields)
    return normalizeSnapshot(merged,current,{preserveItemProvenance=true}),report
end

-- Public pure hooks are installed before any UE4SS startup work. CI sets
-- CRABSYNCV2_TEST_MODE=true and dofile() returns here without timers or writes.
local API = rawget(_G,"CrabSyncV2") or {}
API.version=BUILD_VERSION
API.protocolVersion=PROTOCOL_VERSION
API.test=API.test or {}
API.test.normalizeSnapshot=normalizeSnapshot
API.test.mergeSnapshots=mergeSnapshots
API.test.encodeCarrierBlocks=encodeCarrierBlocks
API.test.decodeCarrierBlock=decodeCarrierBlock
API.test.assembleCarrierBlocks=assembleCarrierBlocks
API.test.encodeSnapshot=encodeSnapshot
API.test.decodeSnapshot=decodeSnapshot
_G.CrabSyncV2=API
if rawget(_G,"CRABSYNCV2_TEST_MODE")==true then return API end

-- --------------------------------------------------------------------------
-- Runtime config and guarded UE4SS access
-- --------------------------------------------------------------------------

local function loadConfig()
    local setters={}
    local booleanKeys={
        "enableCrabSyncV2","allowPeerVisibleStateRead","allowCarrierDiscovery",
        "allowCarrierPublish","allowCarrierReceive","allowHealthRead",
        "allowEquipmentRead","allowResourceRead","allowInventoryRead",
        "allowInventoryItemTraversal","allowMetadataRead","allowEnhancementRead",
        "allowDebugLoopbackTransport","allowApply","allowHealthApply",
        "allowEquipmentApply","allowResourceApply","allowInventoryApply",
        "allowMetadataApply","allowEnhancementApply","allowJoinedClientApply",
        "allowMultiplayerApply","hostOnlyApply","dryRunApply","backupBeforeApply",
        "allowOfficialFunctionApply","allowRawPropertyWrites","allowRawInventoryWrites",
        "allowOnRepInventory","allowOnRepCrystals","allowClientRefreshPSUI",
        "debugCrashBreadcrumbs","debugVerboseSnapshots",
    }
    for _,key in ipairs(booleanKeys) do setters[key]=function(value) CONFIG[key]=(value=="true") end end
    setters.transportMode=function(value)
        local allowed={disabled=true,game_visible=true,p2p_carrier=true,debug_loopback=true}
        CONFIG.transportMode=allowed[value] and value or "disabled"
    end
    local numberBounds={pollIntervalMs={250,10000},stableTicksRequired={1,60},maxSnapshotAgeMs={1000,120000},maxPeers={1,32},maxInventoryItemsPerCategory={1,256}}
    for key,bounds in pairs(numberBounds) do setters[key]=function(value) CONFIG[key]=clampInteger(value,bounds[1],bounds[2]) end end
    local policyValues={
        healthMergePolicy={max_visible=true,sum_visible=true},
        equipmentMergePolicy={lowest_fingerprint=true},
        crystalMergePolicy={max_visible=true,sum_visible=true},
        slotMergePolicy={max_visible=true,sum_visible=true},
        inventoryMergePolicy={preserve_instances=true},
    }
    for key,allowed in pairs(policyValues) do setters[key]=function(value) if allowed[value] then CONFIG[key]=value end end end

    local path=SCRIPT_DIR.."config.txt";local file=io.open(path,"r")
    if not file then log("config","config.txt unavailable; safe defaults remain active");return false end
    local lineNo=0
    for line in file:lines() do
        lineNo=lineNo+1;local clean=trim(line)
        if clean~="" and not clean:match("^[#;]") then
            local key,value=line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
            if key and setters[key] then setters[key](trim(value))
            elseif key then log("config",string.format("line %d unknown key=%s",lineNo,key))
            else log("config",string.format("line %d malformed",lineNo)) end
        end
    end
    file:close()
    if CONFIG.healthMergePolicy=="sum_visible" or CONFIG.crystalMergePolicy=="sum_visible" or CONFIG.slotMergePolicy=="sum_visible" then
        log("config","WARNING sum_visible health/crystals/slots is diagnostics-only and hard-blocked from live apply")
    end
    log("config",string.format(
        "build=%s enabled=%s transport=%s peerRead=%s carrier(discover/publish/receive)=%s/%s/%s reads(H/E/R/I/T/M/X)=%s/%s/%s/%s/%s/%s/%s apply(all/H/E/R/I/M/X)=%s/%s/%s/%s/%s/%s/%s role(joined/multi/hostOnly)=%s/%s/%s dryRun=%s backup=%s",
        BUILD_VERSION,tostring(CONFIG.enableCrabSyncV2),CONFIG.transportMode,
        tostring(CONFIG.allowPeerVisibleStateRead),tostring(CONFIG.allowCarrierDiscovery),
        tostring(CONFIG.allowCarrierPublish),tostring(CONFIG.allowCarrierReceive),
        tostring(CONFIG.allowHealthRead),tostring(CONFIG.allowEquipmentRead),
        tostring(CONFIG.allowResourceRead),tostring(CONFIG.allowInventoryRead),
        tostring(CONFIG.allowInventoryItemTraversal),tostring(CONFIG.allowMetadataRead),
        tostring(CONFIG.allowEnhancementRead),tostring(CONFIG.allowApply),
        tostring(CONFIG.allowHealthApply),tostring(CONFIG.allowEquipmentApply),
        tostring(CONFIG.allowResourceApply),tostring(CONFIG.allowInventoryApply),
        tostring(CONFIG.allowMetadataApply),tostring(CONFIG.allowEnhancementApply),
        tostring(CONFIG.allowJoinedClientApply),tostring(CONFIG.allowMultiplayerApply),
        tostring(CONFIG.hostOnlyApply),tostring(CONFIG.dryRunApply),tostring(CONFIG.backupBeforeApply)))
    return true
end

local function isValidUObject(object)
    if object==nil then return false end
    local ok,valid=pcall(function() return object:IsValid() end)
    return ok and valid==true
end

local function safeGetProperty(object,property)
    if not isValidUObject(object) then return nil,"invalid UObject" end
    local ok,value=pcall(function() return object:GetPropertyValue(property) end)
    if not ok then return nil,"GetPropertyValue("..tostring(property)..") failed: "..tostring(value) end
    return value,nil
end

local function safeSetProperty(object,property,value)
    if not isValidUObject(object) then return false,"invalid UObject" end
    local ok,result=pcall(function() return object:SetPropertyValue(property,value) end)
    if not ok then return false,"SetPropertyValue("..tostring(property)..") failed: "..tostring(result) end
    return true,nil
end

local function safeStructField(structValue,field)
    if structValue==nil then return nil,"nil struct" end
    local ok,value=pcall(function() return structValue[field] end)
    if not ok then return nil,"struct field "..tostring(field).." failed: "..tostring(value) end
    return value,nil
end

local function safeSetStructField(structValue,field,value)
    if structValue==nil then return false,"nil struct" end
    local ok,result=pcall(function() structValue[field]=value end)
    if not ok then return false,"struct write "..tostring(field).." failed: "..tostring(result) end
    return true,nil
end

local function safeCallFunction(object,functionName,...)
    if not isValidUObject(object) then return nil,"invalid UObject" end
    local args={...}
    local ok,result=pcall(function()
        local fn=object[functionName]
        if type(fn)~="function" then error("function unavailable") end
        return fn(object,table.unpack(args))
    end)
    if not ok then return nil,tostring(functionName).." failed: "..tostring(result) end
    return result,nil
end

local function describeObject(object)
    local out={valid=isValidUObject(object),className="",shortName="",fullName=""}
    if not out.valid then return out end
    pcall(function() out.fullName=tostring(object:GetFullName() or "") end)
    pcall(function() out.shortName=tostring(object:GetName() or "") end)
    if out.shortName=="" then pcall(function() out.shortName=tostring(object.Name:ToString() or "") end) end
    pcall(function() local class=object:GetClass();if class then out.className=tostring(class:GetName() or "") end end)
    return out
end

API.isValidUObject=isValidUObject
API.safeGetProperty=safeGetProperty
API.safeStructField=safeStructField
API.describeObject=describeObject

local function safeArrayElement(element)
    if element==nil then return nil,"nil array element" end
    local ok,value=pcall(function() return element:get() end)
    if ok and value~=nil then return value,nil end
    if isValidUObject(element) then return element,nil end
    return nil,"array element wrapper unavailable"
end

local function safeForEachArray(array,cap,callback)
    if array==nil then return 0,"nil array" end
    local count=0;local callbackError=nil
    local ok,err=pcall(function()
        array:ForEach(function(index,element)
            if count>=cap then return end
            count=count+1
            local callbackOk,callbackResult=pcall(callback,index,element)
            if not callbackOk and not callbackError then callbackError=tostring(callbackResult) end
        end)
    end)
    if not ok then return count,"ForEach failed: "..tostring(err) end
    if callbackError then return count,"element read failed: "..callbackError end
    return count,nil
end

local function readFirstProperty(object,names)
    for _,name in ipairs(names) do
        local value,err=safeGetProperty(object,name)
        if not err and value~=nil and tostring(value)~="" then return value,name end
    end
    return nil,""
end

local function fingerprintPlayerState(playerState)
    local stable,stableSource=readFirstProperty(playerState,{"UniqueId","PlayerId","PlatformId","SteamId","NetId"})
    local display,displaySource=readFirstProperty(playerState,{"PlayerName","PlayerNamePrivate","DisplayName","Name"})
    local stableHash,stableLength=fingerprintValue(stable)
    local displayHash,displayLength=fingerprintValue(display)
    local objectDescription=describeObject(playerState)
    local objectHash=fingerprintValue(objectDescription.fullName~="" and objectDescription.fullName or tostring(playerState))
    local fingerprint
    if stableHash~="" then fingerprint="id-"..stableHash
    elseif displayHash~="" then fingerprint="display-"..displayHash
    else fingerprint="object-"..tostring(objectHash) end
    return fingerprint,{
        stableIdSource=stableSource,stableIdFingerprint=stableHash,stableIdLength=stableLength,
        displayNameSource=displaySource,displayNameFingerprint=displayHash,displayNameLength=displayLength,
        objectFingerprint=tostring(objectHash),rawIdentityEmitted=false,
    }
end

local function sameObject(left,right)
    if left==nil or right==nil then return false end
    local ok,equal=pcall(function() return left==right end)
    return ok and equal==true
end

local function getLocalPlayerState()
    local ok,pc=pcall(function() return FindFirstOf("CrabPC") end)
    if not ok or not isValidUObject(pc) then return nil,nil,"CrabPC unavailable" end
    local ps,err=safeGetProperty(pc,"PlayerState")
    if err or not isValidUObject(ps) then return pc,nil,"CrabPC.PlayerState unavailable" end
    return pc,ps,nil
end

-- Adapted from RuntimeProbe collectResourceVisibilityCandidates: dedupe capped
-- candidates from PlayerState/CrabPS and Controller.PlayerState paths.
local function discoverPeers()
    local candidates,seen={},{}
    local function add(playerState,sourcePath)
        if #candidates>=CONFIG.maxPeers or not isValidUObject(playerState) then return end
        local internalKey=tostring(playerState)
        if seen[internalKey] then return end
        seen[internalKey]=true
        local fingerprint,identity=fingerprintPlayerState(playerState)
        candidates[#candidates+1]={object=playerState,sourcePath=sourcePath,fingerprint=fingerprint,identity=identity}
    end
    local _,localPS=getLocalPlayerState();add(localPS,"CrabPC.PlayerState")
    if type(FindAllOf)=="function" then
        for _,className in ipairs({"PlayerState","CrabPS"}) do
            local ok,objects=pcall(function() return FindAllOf(className) end)
            if ok and type(objects)=="table" then
                for _,element in ipairs(objects) do local object=safeArrayElement(element);add(object,"FindAllOf("..className..")") end
            end
        end
        for _,className in ipairs({"PlayerController","CrabPC"}) do
            local ok,objects=pcall(function() return FindAllOf(className) end)
            if ok and type(objects)=="table" then
                for _,element in ipairs(objects) do
                    local controller=safeArrayElement(element)
                    if isValidUObject(controller) then local ps=safeGetProperty(controller,"PlayerState");add(ps,"FindAllOf("..className..").PlayerState") end
                end
            end
        end
    end
    table.sort(candidates,function(a,b) if a.fingerprint==b.fingerprint then return a.sourcePath<b.sourcePath end;return a.fingerprint<b.fingerprint end)
    log("peer",string.format("discovered=%d cap=%d fingerprints=%s rawIdentityEmitted=false",#candidates,CONFIG.maxPeers,(function() local p={};for _,c in ipairs(candidates) do p[#p+1]=c.fingerprint end;return table.concat(p,",") end)()))
    return candidates
end

local function detectRole(pc,localPS,peers)
    local authority=nil
    if isValidUObject(pc) then local value,err=safeCallFunction(pc,"HasAuthority");if not err and type(value)=="boolean" then authority=value end end
    if authority==nil and isValidUObject(localPS) then local value,err=safeCallFunction(localPS,"HasAuthority");if not err and type(value)=="boolean" then authority=value end end
    if authority==false then return "joined-client" end
    if authority==true then return (#peers>1) and "host" or "solo" end
    return "unknown"
end

local function computeSessionId(peers)
    local world="unknown"
    for _,className in ipairs({"CrabGS","GameStateBase","GameState"}) do
        local ok,object=pcall(function() return FindFirstOf(className) end)
        if ok and isValidUObject(object) then world=describeObject(object).fullName;break end
    end
    local identities={};for _,peer in ipairs(peers) do identities[#identities+1]=peer.fingerprint end;table.sort(identities)
    local hash=fingerprintValue(world.."|"..table.concat(identities,","))
    return "session-"..tostring(hash)
end

local ENHANCEMENT_VALUES={None=0,Bouncing=1,Accelerating=2,Zigging=3,Spiraling=4,Snaking=5,Returning=6,Orbiting=7,Chipping=8,Sticky=9,Growing=10,Freezing=11,Flaming=12,Electrifying=13,Toxifying=14,Arcanifying=15,Persisting=16,Doubling=17,Targeting=18,Damaging=19,Booming=20,Tripling=21,Splitting=22,Scattering=23,Expanding=24,Homing=25,Endangering=26,Random=27}

local function normalizeEnhancementRuntime(value)
    if isFinite(value) then
        local number=tonumber(value)
        if number==math.floor(number) and number>=0 and number<=ENHANCEMENT_MAX then return number end
        return nil
    end
    local text=tostring(value or "");local name=text:match("ECrabEnhancementType::([%w_]+)") or text:match("([%w_]+)$")
    return name and ENHANCEMENT_VALUES[name] or nil
end

local function readDA(object)
    local description=describeObject(object)
    return {supported=description.valid,shortName=description.shortName,fullName=description.fullName}
end

local function readHealth(playerState,snapshot)
    local health={supported=false,armorSupported=false,unsupportedFields={}}
    if not CONFIG.allowHealthRead then addUnsupported(health,"health","category disabled");return health end
    local info,err=safeGetProperty(playerState,"HealthInfo")
    if err or info==nil then addUnsupported(health,"HealthInfo",err or "nil");return health end
    local fields={CurrentHealth="currentHealth",CurrentMaxHealth="currentMaxHealth",PreviousHealth="previousHealth",PreviousMaxHealth="previousMaxHealth"}
    for source,target in pairs(fields) do local value,fieldErr=safeStructField(info,source);if not fieldErr and isFinite(value) then health[target]=tonumber(value) else addUnsupported(health,"HealthInfo."..source,fieldErr or "non-finite") end end
    for source,target in pairs({BaseMaxHealth="baseMaxHealth",MaxHealthMultiplier="maxHealthMultiplier"}) do local value,fieldErr=safeGetProperty(playerState,source);if not fieldErr and isFinite(value) then health[target]=tonumber(value) else addUnsupported(health,source,fieldErr or "non-finite") end end
    -- Armor is observed when present, but remains policy-unresolved and never applied.
    health.armor={}
    local armorSeen=false
    for source,target in pairs({CurrentArmorPlates="currentPlates",CurrentArmorPlateHealth="currentPlateHealth",PreviousArmorPlateHealth="previousPlateHealth"}) do local value,fieldErr=safeStructField(info,source);if not fieldErr and isFinite(value) then health.armor[target]=tonumber(value);armorSeen=true else addUnsupported(health,"HealthInfo."..source,fieldErr or "unavailable") end end
    health.armorObserved=armorSeen;health.armorSupported=false
    health.supported=(health.currentHealth~=nil and health.currentMaxHealth~=nil)
    if not health.supported then addUnsupported(health,"health","required current/max pair incomplete") end
    return health
end

local function readEquipment(playerState)
    local equipment={supported=false,weapon=normalizeDA(nil),ability=normalizeDA(nil),melee=normalizeDA(nil),unsupportedFields={}}
    if not CONFIG.allowEquipmentRead then addUnsupported(equipment,"equipment","category disabled");return equipment end
    for property,key in pairs({WeaponDA="weapon",AbilityDA="ability",MeleeDA="melee"}) do
        local value,err=safeGetProperty(playerState,property)
        if not err and value~=nil then equipment[key]=readDA(value);equipment.supported=equipment.supported or equipment[key].supported
        else addUnsupported(equipment,property,err or "nil") end
    end
    return equipment
end

local function readResources(playerState)
    local resources={supported=false,crystals=nil,slots={weaponMods=nil,abilityMods=nil,meleeMods=nil,perks=nil},keysSupported=false,unsupportedFields={"Keys:excluded by CrabSyncV2 policy"}}
    if not CONFIG.allowResourceRead then addUnsupported(resources,"resources","category disabled");return resources end
    local crystals,err=safeGetProperty(playerState,"Crystals")
    if not err and isFinite(crystals) then resources.crystals=clampInteger(crystals,0,UINT32_MAX);resources.supported=true else addUnsupported(resources,"Crystals",err or "non-finite") end
    for property,key in pairs({NumWeaponModSlots="weaponMods",NumAbilityModSlots="abilityMods",NumMeleeModSlots="meleeMods",NumPerkSlots="perks"}) do
        local value,slotErr=safeGetProperty(playerState,property)
        if not slotErr and isFinite(value) then resources.slots[key]=clampInteger(value,0,BYTE_MAX);resources.supported=true else addUnsupported(resources,property,slotErr or "non-finite") end
    end
    return resources
end

local function readEnhancementArrayRuntime(array)
    if array==nil then return nil,false,"Enhancements nil" end
    local okBefore,before=pcall(function() return #array end)
    if not okBefore or not isFinite(before) then return nil,false,"Enhancements count unavailable" end
    before=clampInteger(before,0,UINT32_MAX)
    if before>BYTE_MAX then return nil,false,"Enhancements exceeds safe traversal limit" end
    local values={};local _,err=safeForEachArray(array,BYTE_MAX,function(_,element)
        local raw=element;local ok,value=pcall(function() return element:get() end);if ok then raw=value end
        local normalized=normalizeEnhancementRuntime(raw);if normalized==nil then error("unsupported enhancement value") end
        values[#values+1]=normalized
    end)
    if err then return nil,false,err end
    local okAfter,after=pcall(function() return #array end)
    if not okAfter or not isFinite(after) or clampInteger(after,0,UINT32_MAX)~=before or #values~=before then return nil,false,"Enhancements changed or truncated during traversal" end
    return values,true,nil
end

local function readInventoryItem(slot,index,category,snapshot)
    local item={
        category=category.key,sourcePlayer=snapshot.sourcePlayerFingerprint,
        visibilityClass=snapshot.visibilityClass,lifecycleGeneration=snapshot.lifecycleGeneration,
        index=isFinite(index) and clampInteger(index,0,UINT32_MAX) or nil,
        daShortName="",daFullName="",level=nil,levelKnown=false,
        accumulatedBuff=nil,accumulatedBuffKnown=false,enhancements=nil,
        enhancementsKnown=false,metadataStatus="unsupported",unsupportedFields={},
    }
    local da,daErr=safeGetProperty(slot,category.daField)
    if daErr or da==nil then da,daErr=safeStructField(slot,category.daField) end
    if da~=nil then local identity=readDA(da);item.daShortName=identity.shortName;item.daFullName=identity.fullName end
    if item.daShortName=="" and item.daFullName=="" then addUnsupported(item,category.daField,daErr or "identity unavailable") end
    if not CONFIG.allowMetadataRead then addUnsupported(item,"InventoryInfo","metadata read disabled");return item end
    local info,infoErr=safeGetProperty(slot,"InventoryInfo")
    if infoErr or info==nil then info,infoErr=safeStructField(slot,"InventoryInfo") end
    if info==nil then addUnsupported(item,"InventoryInfo",infoErr or "nil");return item end
    local level,levelErr=safeStructField(info,"Level")
    if not levelErr and isFinite(level) then item.level=clampInteger(level,1,BYTE_MAX);item.levelKnown=true else addUnsupported(item,"InventoryInfo.Level",levelErr or "non-finite") end
    local accum,accumErr=safeStructField(info,"AccumulatedBuff")
    if not accumErr and isFinite(accum) then item.accumulatedBuff=tonumber(accum);item.accumulatedBuffKnown=true else addUnsupported(item,"InventoryInfo.AccumulatedBuff",accumErr or "non-finite") end
    if CONFIG.allowEnhancementRead then
        local enhancementArray,enhancementErr=safeStructField(info,"Enhancements")
        if not enhancementErr then
            local values,known,readErr=readEnhancementArrayRuntime(enhancementArray)
            if known then item.enhancements=values;item.enhancementsKnown=true else addUnsupported(item,"InventoryInfo.Enhancements",readErr) end
        else addUnsupported(item,"InventoryInfo.Enhancements",enhancementErr) end
    else addUnsupported(item,"InventoryInfo.Enhancements","enhancement read disabled") end
    local known=(item.levelKnown and 1 or 0)+(item.accumulatedBuffKnown and 1 or 0)+(item.enhancementsKnown and 1 or 0)
    item.metadataStatus=(known==3 and "ok") or (known>0 and "partial") or "unsupported"
    return item
end

local function readInventory(playerState,snapshot)
    local inventory={supported=false,counts={},categorySupported={},weaponMods={},abilityMods={},meleeMods={},perks={},relics={},unsupportedFields={}}
    if not CONFIG.allowInventoryRead then addUnsupported(inventory,"inventory","category disabled");return inventory end
    for _,category in ipairs(INVENTORY_CATEGORIES) do
        local array,err=safeGetProperty(playerState,category.property)
        inventory.categorySupported[category.key]=false
        if err or array==nil then addUnsupported(inventory,category.property,err or "nil")
        else
            local okLength,length=pcall(function() return #array end)
            if okLength and isFinite(length) then inventory.counts[category.key]=clampInteger(length,0,UINT32_MAX) else addUnsupported(inventory,category.property..".count","unavailable") end
            if CONFIG.allowInventoryItemTraversal then
                breadcrumb("inventory traversal "..category.property,"enter")
                local count,traverseErr=safeForEachArray(array,CONFIG.maxInventoryItemsPerCategory,function(index,element)
                    local slot,slotErr=safeArrayElement(element);if not slot then error(slotErr) end
                    inventory[category.key][#inventory[category.key]+1]=readInventoryItem(slot,index,category,snapshot)
                end)
                breadcrumb("inventory traversal "..category.property,"leave")
                local okAfter,lengthAfter=pcall(function() return #array end)
                local expected=inventory.counts[category.key]
                local complete=not traverseErr and expected~=nil and okAfter and isFinite(lengthAfter)
                    and expected==count and clampInteger(lengthAfter,0,UINT32_MAX)==expected
                    and expected<=CONFIG.maxInventoryItemsPerCategory
                if complete then inventory.categorySupported[category.key]=true;inventory.supported=true
                else
                    inventory[category.key]={}
                    addUnsupported(inventory,category.property..".traversal",traverseErr or "count changed, capped, or unavailable during traversal")
                end
            else addUnsupported(inventory,category.property..".traversal","item traversal disabled") end
        end
    end
    return inventory
end

local function buildVisibleSnapshot(peer,localPS,role,sessionId)
    local localRow=sameObject(peer.object,localPS)
    local snapshot={
        protocolVersion=PROTOCOL_VERSION,sessionId=sessionId,clientInstanceId=runtime.clientInstanceId,
        sourcePlayerFingerprint=peer.fingerprint,sourceRole=localRow and role or "unknown",
        lifecycleGeneration=runtime.lifecycleGeneration,timestampMs=nowMs(),tick=runtime.tick,
        visibilityClass=localRow and "local_only" or "peer_visible",
        evidenceConfidence=localRow and "runtime_safe_local" or "runtime_safe_remote_visible",
        transportMode="game_visible",partial=false,unsupportedFields={},carrier={},
    }
    snapshot.health=readHealth(peer.object,snapshot)
    snapshot.equipment=readEquipment(peer.object)
    snapshot.resources=readResources(peer.object)
    snapshot.inventory=readInventory(peer.object,snapshot)
    if not localRow and not snapshot.inventory.supported then addUnsupported(snapshot,"inventory","remote metadata unavailable") end
    local normalized,reason=normalizeSnapshot(snapshot,snapshot.timestampMs)
    if not normalized then return nil,reason end
    return normalized
end

local function readVisiblePeerSnapshots(peers,localPS,role,sessionId)
    local rows={}
    for _,peer in ipairs(peers) do
        local snapshot,reason=buildVisibleSnapshot(peer,localPS,role,sessionId)
        if snapshot then rows[#rows+1]=snapshot;log("peer",string.format("row=%s visibility=%s health=%s equipment=%s resources=%s inventory=%s unsupported=%d",snapshot.sourcePlayerFingerprint,snapshot.visibilityClass,tostring(snapshot.health.supported),tostring(snapshot.equipment.supported),tostring(snapshot.resources.supported),tostring(snapshot.inventory.supported),#snapshot.unsupportedFields))
        else log("error","visible snapshot skipped fingerprint="..peer.fingerprint.." reason="..tostring(reason)) end
    end
    return rows
end

-- Carrier discovery is deliberately narrow and read-only. No candidate is
-- promoted beyond objectdump/read-discovered without multiplayer evidence.
local CARRIER_CANDIDATE_SPECS={
    {class="CrabPS",field="PlayerTintType",reason="cosmetic/display enum",criticality="user-visible",status="unproven"},
    {class="CrabPS",field="CrabSkin",reason="cosmetic DataAsset",criticality="save/user-visible",status="blocked"},
    {class="PlayerState",field="Score",reason="replicated display scalar",criticality="gameplay-authoritative",status="unsafe"},
    {class="PlayerState",field="CompressedPing",reason="replicated transient scalar",criticality="network-authoritative",status="unsafe"},
    {class="CrabPS",field="IslandRewardRarity",reason="replicated status enum",criticality="gameplay-authoritative",status="unsafe"},
}

local function discoverCarrierCandidates(peers)
    local results={}
    for _,spec in ipairs(CARRIER_CANDIDATE_SPECS) do
        local visible,remoteVisible=0,0;local localVisible=false;local kinds={}
        for _,peer in ipairs(peers or {}) do
            local value,err=safeGetProperty(peer.object,spec.field)
            if not err and value~=nil then
                visible=visible+1;kinds[type(value)]=true
                if peer.sourcePath=="CrabPC.PlayerState" then localVisible=true else remoteVisible=remoteVisible+1 end
            end
        end
        local kindList={};for kind,_ in pairs(kinds) do kindList[#kindList+1]=kind end;table.sort(kindList)
        local result={candidatePath=spec.class.."."..spec.field,reason=spec.reason,localVisibility=localVisible and "observed" or "unresolved",hostVisibility="unproven",joinedClientVisibility="unproven",remoteVisibility=(remoteVisible>0 and "read-observed" or "unproven"),likelyPayloadCapacity="unknown",lifecycleBehavior="unknown",gameplayCriticality=spec.criticality,status=spec.status,valueKinds=kindList,visibleRows=visible,remoteVisibleRows=remoteVisible}
        results[#results+1]=result
        log("carrier",string.format("candidate=%s reason=%s local=%s host=%s joined=%s remote=%s capacity=%s lifecycle=%s criticality=%s status=%s",result.candidatePath,result.reason,result.localVisibility,result.hostVisibility,result.joinedClientVisibility,result.remoteVisibility,result.likelyPayloadCapacity,result.lifecycleBehavior,result.gameplayCriticality,result.status))
    end
    log("carrier","no usable carrier candidate; publish remains blocked")
    runtime.lastCarrierCandidates=results
    return results
end

local function publishSnapshot(snapshot)
    if CONFIG.transportMode=="debug_loopback" then
        if not CONFIG.allowDebugLoopbackTransport then return false,"debug loopback disabled" end
        if not runtime.loopbackInjected then runtime.loopbackRows={deepCopy(snapshot)} end
        return true,nil
    end
    if CONFIG.transportMode=="game_visible" then return true,"game-visible state publishes through vanilla replication" end
    if CONFIG.transportMode=="p2p_carrier" then
        if not CONFIG.allowCarrierPublish then return false,"carrier publish disabled" end
        return false,"carrier unavailable: no approved candidate"
    end
    return false,"transport disabled"
end

local function readPeerSnapshots(peers,localPS,role,sessionId)
    if CONFIG.transportMode=="debug_loopback" then
        if not CONFIG.allowDebugLoopbackTransport then return {},"debug loopback disabled" end
        local rows={};for _,row in ipairs(runtime.loopbackRows) do local copy=deepCopy(row);copy.transportMode="debug_loopback";rows[#rows+1]=copy end;return rows,nil
    end
    if CONFIG.transportMode=="game_visible" or CONFIG.transportMode=="p2p_carrier" then
        if not CONFIG.allowPeerVisibleStateRead then return {},"peer visible-state read disabled" end
        local rows=readVisiblePeerSnapshots(peers,localPS,role,sessionId)
        if CONFIG.transportMode=="p2p_carrier" and CONFIG.allowCarrierReceive then log("carrier","receive skipped: no approved readable candidate") end
        return rows,nil
    end
    -- Disabled transport still permits one local diagnostics row.
    for _,peer in ipairs(peers) do if sameObject(peer.object,localPS) then local row,reason=buildVisibleSnapshot(peer,localPS,role,sessionId);return row and {row} or {},reason end end
    return {},"local PlayerState absent"
end

API.discoverPeers=discoverPeers
API.readVisiblePeerSnapshots=readVisiblePeerSnapshots
API.discoverCarrierCandidates=discoverCarrierCandidates
API.publishSnapshot=publishSnapshot
API.readPeerSnapshots=readPeerSnapshots
API.encodeSnapshot=encodeSnapshot
API.decodeSnapshot=decodeSnapshot
API.mergeSnapshots=mergeSnapshots

-- --------------------------------------------------------------------------
-- Convergence/apply planning
-- --------------------------------------------------------------------------

local function daIdentity(value)
    if type(value)~="table" then return "" end
    return value.fullName~="" and value.fullName or tostring(value.shortName or "")
end

local function appendReason(category,kind,reason)
    category[kind]=category[kind] or {}
    category[kind][#category[kind]+1]=tostring(reason)
end

local function sortedComparisonSignatures(items)
    local out={}
    for _,item in ipairs(items or {}) do
        local complete=item.levelKnown and item.accumulatedBuffKnown and item.enhancementsKnown
        out[#out+1]=exactMetadataSignature(item,not complete)
    end
    table.sort(out);return out
end

local function arraysEqual(left,right)
    if #left~=#right then return false end
    for index=1,#left do if left[index]~=right[index] then return false end end
    return true
end

local function inventoryHasUnknown(items)
    for _,item in ipairs(items or {}) do
        if not item.levelKnown then return true,"unknown Level for "..itemIdentity(item) end
        if not item.accumulatedBuffKnown then return true,"unknown AccumulatedBuff for "..itemIdentity(item) end
        if not item.enhancementsKnown then return true,"unknown Enhancements for "..itemIdentity(item) end
        if tostring(item.daFullName or "")=="" then return true,"full DataAsset identity unavailable for "..tostring(item.daShortName or "unknown item") end
    end
    return false,nil
end

local function inventoryHasDuplicateIdentity(items)
    local counts={}
    for _,item in ipairs(items or {}) do
        local identity=itemIdentity(item)
        if identity~="" then counts[identity]=(counts[identity] or 0)+1;if counts[identity]>1 then return true,identity end end
    end
    return false,nil
end

local function buildApplyPlan(localSnapshot,merged,context,mergeReport)
    local plan={
        version=BUILD_VERSION,timestampMs=nowMs(),lifecycleGeneration=runtime.lifecycleGeneration,
        role=context.role,sessionId=context.sessionId,transportMode=CONFIG.transportMode,changes=0,
        mergeAccepted=(mergeReport and mergeReport.accepted) or 0,
        globalSkips={},mergeRejected=deepCopy((mergeReport and mergeReport.rejected) or {}),
        categories={
            health={actions={},skips={}},equipment={actions={},skips={}},
            resources={actions={},skips={}},inventory={actions={},skips={}},
        },
    }
    local function global(reason) plan.globalSkips[#plan.globalSkips+1]=reason end
    if not CONFIG.enableCrabSyncV2 then global("CrabSyncV2 disabled") end
    if runtime.lifecycleState~="stable" then global("lifecycle instability: "..runtime.lifecycleState) end
    if not isValidUObject(context.playerState) then global("invalid PlayerState") end
    if localSnapshot.lifecycleGeneration~=runtime.lifecycleGeneration then global("local lifecycle generation mismatch") end
    if merged.lifecycleGeneration~=runtime.lifecycleGeneration then global("merged lifecycle generation mismatch") end
    if localSnapshot.sessionId~=context.sessionId or merged.sessionId~=context.sessionId then global("session fingerprint mismatch") end
    if CONFIG.transportMode=="disabled" then global("transport not ready: disabled") end
    if CONFIG.transportMode=="debug_loopback" then global("transport not ready: debug loopback is diagnostics-only") end
    if CONFIG.transportMode=="p2p_carrier" then global("carrier not ready: no approved candidate") end
    if context.role=="unknown" then global("role not allowed: unknown") end
    if context.role=="joined-client" and not CONFIG.allowJoinedClientApply then global("role not allowed: joined-client apply disabled") end
    if context.role~="solo" and not CONFIG.allowMultiplayerApply then global("role not allowed: multiplayer apply disabled") end
    if CONFIG.hostOnlyApply and context.role~="solo" and context.role~="host" then global("role not allowed: host-only apply") end
    if not CONFIG.allowApply then global("apply disabled by config") end
    if CONFIG.dryRunApply then global("dry-run mode") end
    if not CONFIG.backupBeforeApply then global("backup required before every real apply") end
    if CONFIG.healthMergePolicy=="sum_visible" or CONFIG.crystalMergePolicy=="sum_visible" or CONFIG.slotMergePolicy=="sum_visible" then global("diagnostics-only sum_visible policy cannot authorize apply") end
    for _,rejected in ipairs(plan.mergeRejected) do
        if rejected.reason=="stale snapshot" then global("stale peer snapshot rejected index="..tostring(rejected.index))
        elseif rejected.reason=="partial snapshot" then global("partial peer snapshot rejected index="..tostring(rejected.index))
        elseif rejected.reason=="lifecycle generation mismatch" then global("old-generation peer snapshot rejected index="..tostring(rejected.index)) end
    end

    local healthPlan=plan.categories.health
    if not CONFIG.allowHealthApply then appendReason(healthPlan,"skips","category disabled by config: health apply") end
    if not merged.health.supported then appendReason(healthPlan,"skips","unsupported field: merged health incomplete")
    elseif not localSnapshot.health.supported then appendReason(healthPlan,"skips","unsupported field: local health incomplete")
    else
        if formatNumber(localSnapshot.health.currentHealth)~=formatNumber(merged.health.currentHealth) then healthPlan.actions[#healthPlan.actions+1]={kind="health mismatch",field="CurrentHealth",from=localSnapshot.health.currentHealth,to=merged.health.currentHealth};plan.changes=plan.changes+1 end
        if formatNumber(localSnapshot.health.currentMaxHealth)~=formatNumber(merged.health.currentMaxHealth) then healthPlan.actions[#healthPlan.actions+1]={kind="health mismatch",field="CurrentMaxHealth",from=localSnapshot.health.currentMaxHealth,to=merged.health.currentMaxHealth};plan.changes=plan.changes+1 end
        if localSnapshot.health.baseMaxHealth~=merged.health.baseMaxHealth then appendReason(healthPlan,"skips","BaseMaxHealth mismatch; write path unproven") end
        if localSnapshot.health.maxHealthMultiplier~=merged.health.maxHealthMultiplier then appendReason(healthPlan,"skips","MaxHealthMultiplier mismatch; write path unproven") end
        appendReason(healthPlan,"skips","armor policy unresolved; armor never applied")
    end

    local equipmentPlan=plan.categories.equipment
    if not CONFIG.allowEquipmentApply then appendReason(equipmentPlan,"skips","category disabled by config: equipment apply") end
    for _,key in ipairs({"weapon","ability","melee"}) do
        local current,target=localSnapshot.equipment[key],merged.equipment[key]
        if not target or not target.supported then appendReason(equipmentPlan,"skips","unsupported field: "..key)
        elseif daIdentity(current)~=daIdentity(target) then equipmentPlan.actions[#equipmentPlan.actions+1]={kind="equipment mismatch",field=key,from=daIdentity(current),to=daIdentity(target)};plan.changes=plan.changes+1 end
    end

    local resourcePlan=plan.categories.resources
    if not CONFIG.allowResourceApply then appendReason(resourcePlan,"skips","category disabled by config: resource apply") end
    if merged.resources.crystals==nil then appendReason(resourcePlan,"skips","unsupported field: Crystals")
    elseif localSnapshot.resources.crystals~=merged.resources.crystals then resourcePlan.actions[#resourcePlan.actions+1]={kind="crystal mismatch",field="Crystals",from=localSnapshot.resources.crystals,to=merged.resources.crystals};plan.changes=plan.changes+1 end
    for _,key in ipairs({"weaponMods","abilityMods","meleeMods","perks"}) do
        local current,target=localSnapshot.resources.slots[key],merged.resources.slots[key]
        if target==nil then appendReason(resourcePlan,"skips","unsupported field: slots."..key)
        elseif current~=target then resourcePlan.actions[#resourcePlan.actions+1]={kind="slot mismatch",field=key,from=current,to=target};plan.changes=plan.changes+1 end
    end
    appendReason(resourcePlan,"skips","Keys excluded by policy")

    local inventoryPlan=plan.categories.inventory
    if not CONFIG.allowInventoryApply then appendReason(inventoryPlan,"skips","category disabled by config: inventory apply") end
    if not merged.inventory.supported then appendReason(inventoryPlan,"skips","unsupported field: merged inventory unavailable") end
    inventoryPlan.multiplayerBlocked=plan.role~="solo" or plan.mergeAccepted>1
    if inventoryPlan.multiplayerBlocked then appendReason(inventoryPlan,"skips","multiplayer inventory apply blocked: stable origin/contribution ledger unavailable") end
    for _,category in ipairs(INVENTORY_CATEGORIES) do
        local localItems=localSnapshot.inventory[category.key] or {}
        local targetItems=merged.inventory[category.key] or {}
        local localSignatures=sortedComparisonSignatures(localItems)
        local targetSignatures=sortedComparisonSignatures(targetItems)
        local unknown,unknownReason=inventoryHasUnknown(targetItems)
        local localUnknown,localUnknownReason=inventoryHasUnknown(localItems)
        local duplicate,duplicateIdentity=inventoryHasDuplicateIdentity(targetItems)
        local localDuplicate,localDuplicateIdentity=inventoryHasDuplicateIdentity(localItems)
        local categoryResult={category=category.key,kind="same",localCount=#localItems,targetCount=#targetItems,unsafe=false,reasons={}}
        local localSupported=localSnapshot.inventory.categorySupported and localSnapshot.inventory.categorySupported[category.key]
        local targetSupported=merged.inventory.categorySupported and merged.inventory.categorySupported[category.key]
        if not localSupported then categoryResult.unsafe=true;categoryResult.reasons[#categoryResult.reasons+1]="unsupported field: local category incomplete" end
        if not targetSupported then categoryResult.unsafe=true;categoryResult.reasons[#categoryResult.reasons+1]="unsupported field: merged category incomplete" end
        if unknown then categoryResult.unsafe=true;categoryResult.reasons[#categoryResult.reasons+1]="unsupported field: "..unknownReason end
        if localUnknown then categoryResult.unsafe=true;categoryResult.reasons[#categoryResult.reasons+1]="backup unsafe: "..localUnknownReason end
        if duplicate then categoryResult.unsafe=true;categoryResult.reasons[#categoryResult.reasons+1]="duplicate ambiguity: "..duplicateIdentity end
        if localDuplicate then categoryResult.unsafe=true;categoryResult.reasons[#categoryResult.reasons+1]="local duplicate ambiguity: "..localDuplicateIdentity end
        if localSupported and targetSupported and #localItems~=#targetItems then categoryResult.kind="inventory item mismatch";categoryResult.unsafe=true;categoryResult.reasons[#categoryResult.reasons+1]="unsafe item pairing: array resize/raw rebuild unsupported"
        elseif localSupported and targetSupported and not arraysEqual(localSignatures,targetSignatures) then
            categoryResult.kind="metadata or identity mismatch"
            local localIdentities,targetIdentities={},{}
            for _,item in ipairs(localItems) do localIdentities[#localIdentities+1]=itemIdentity(item) end
            for _,item in ipairs(targetItems) do targetIdentities[#targetIdentities+1]=itemIdentity(item) end
            table.sort(localIdentities);table.sort(targetIdentities)
            if not arraysEqual(localIdentities,targetIdentities) then categoryResult.unsafe=true;categoryResult.reasons[#categoryResult.reasons+1]="inventory item mismatch: identity replacement pairing unproven"
            else
                categoryResult.reasons[#categoryResult.reasons+1]="metadata mismatch"
                local enhancementMismatch=false
                for _,signature in ipairs(targetSignatures) do if not (function() for _,localSignature in ipairs(localSignatures) do if localSignature==signature then return true end end;return false end)() then enhancementMismatch=true;break end end
                if enhancementMismatch then categoryResult.reasons[#categoryResult.reasons+1]="enhancement mismatch possible" end
            end
        end
        if categoryResult.kind~="same" then inventoryPlan.actions[#inventoryPlan.actions+1]=categoryResult;plan.changes=plan.changes+1 end
        for _,reason in ipairs(categoryResult.reasons) do appendReason(inventoryPlan,"skips",category.key..": "..reason) end
    end
    if CONFIG.transportMode=="p2p_carrier" and CONFIG.allowCarrierReceive and not runtime.carrierReady then appendReason(inventoryPlan,"skips","carrier not ready: no approved candidate") end

    log("plan",string.format("role=%s lifecycle=%s transport=%s changes=%d globalSkips=%d H=%d E=%d R=%d I=%d",plan.role,runtime.lifecycleState,plan.transportMode,plan.changes,#plan.globalSkips,#healthPlan.actions,#equipmentPlan.actions,#resourcePlan.actions,#inventoryPlan.actions))
    for _,reason in ipairs(plan.globalSkips) do log("plan","global skip: "..reason) end
    for name,category in pairs(plan.categories) do for _,action in ipairs(category.actions) do log("plan",name.." action="..tostring(action.kind).." field="..tostring(action.field or action.category or "")) end;for _,reason in ipairs(category.skips) do log("plan",name.." skip="..reason) end end
    runtime.lastPlan=plan
    return plan
end

API.buildApplyPlan=buildApplyPlan

-- --------------------------------------------------------------------------
-- Backup and guarded best-effort executor
-- --------------------------------------------------------------------------

local backupSequence=0
local function writeBackup(snapshot)
    backupSequence=backupSequence+1
    local encoded,reason=encodeSnapshot(snapshot)
    if not encoded then return nil,"backup encode failed: "..tostring(reason) end
    local safeInstance=tostring(runtime.clientInstanceId):gsub("[^%w_%-]","_")
    local path=string.format("%scrabsyncv2_backup_%s_%04d.cs2",BACKUP_DIR,safeInstance,backupSequence)
    local file,openReason=io.open(path,"wb")
    if not file then return nil,"backup open failed: "..tostring(openReason) end
    local ok,writeReason=pcall(function() file:write(encoded);file:close() end)
    if not ok then pcall(function() file:close() end);return nil,"backup write failed: "..tostring(writeReason) end
    runtime.lastBackupPath=path;log("backup","path="..path);return path,nil
end

local function findDataAsset(className,target)
    local identity=type(target)=="table" and target or {}
    local fullName=tostring(identity.fullName or "")
    if fullName=="" then return nil,"full DataAsset identity required; short-name lookup is blocked" end
    local ok,objects=pcall(function() return FindAllOf(className) end)
    if not ok or type(objects)~="table" then return nil,"FindAllOf("..className..") unavailable" end
    for _,object in ipairs(objects) do
        local candidate=safeArrayElement(object)
        if isValidUObject(candidate) then
            local described=readDA(candidate)
            if described.fullName==fullName then return candidate,nil end
        end
    end
    return nil,"DataAsset not found: "..daIdentity(identity)
end

local function collectLiveSlots(playerState,category,snapshot)
    local slots={};local array,err=safeGetProperty(playerState,category.property)
    if err or array==nil then return nil,err or "array nil" end
    local okBefore,before=pcall(function() return #array end)
    if not okBefore or not isFinite(before) then return nil,"live array count unavailable" end
    before=clampInteger(before,0,UINT32_MAX)
    local expected=snapshot.inventory.counts and snapshot.inventory.counts[category.key]
    if expected==nil or before~=expected or before>CONFIG.maxInventoryItemsPerCategory then return nil,"live array count changed, unavailable, or exceeds traversal cap" end
    local _,traverseErr=safeForEachArray(array,CONFIG.maxInventoryItemsPerCategory,function(index,element)
        local slot,slotErr=safeArrayElement(element);if not slot then error(slotErr) end
        local item=readInventoryItem(slot,index,category,snapshot)
        local info=safeGetProperty(slot,"InventoryInfo");if info==nil then info=safeStructField(slot,"InventoryInfo") end
        slots[#slots+1]={slot=slot,info=info,item=item,index=isFinite(index) and tonumber(index) or #slots}
    end)
    if traverseErr then return nil,traverseErr end
    local okAfter,after=pcall(function() return #array end)
    if not okAfter or not isFinite(after) or clampInteger(after,0,UINT32_MAX)~=before or #slots~=before then return nil,"live array changed or truncated during pairing read" end
    table.sort(slots,function(a,b) return a.index<b.index end)
    return slots,nil
end

local function writeEnhancements(info,wanted)
    local array,err=safeStructField(info,"Enhancements");if err or array==nil then return false,err or "Enhancements unavailable" end
    local original,known,readErr=readEnhancementArrayRuntime(array);if not known then return false,"cannot snapshot Enhancements: "..tostring(readErr) end
    local function clear()
        local ok=pcall(function() array:Empty() end);if ok then return true end
        ok=pcall(function() array:SetArrayNum(0) end);return ok
    end
    if not clear() then return false,"Enhancements clear unsupported" end
    for _,value in ipairs(wanted or {}) do
        local normalized=normalizeEnhancementRuntime(value)
        if normalized==nil then clear();for _,old in ipairs(original or {}) do pcall(function() array:Add(old) end) end;return false,"Enhancements contains invalid enum; rollback attempted" end
        local okAdd,addErr=pcall(function() array:Add(normalized) end)
        if not okAdd then
            clear();for _,old in ipairs(original or {}) do pcall(function() array:Add(old) end) end
            return false,"Enhancements add failed; rollback attempted: "..tostring(addErr)
        end
    end
    return true,nil
end

local function executeApplyPlan(playerState,localSnapshot,merged,plan)
    local result={applied={},skipped={},errors={},backupPath=nil}
    local function skip(category,reason) result.skipped[#result.skipped+1]=category..": "..reason;log("apply","skip "..category..": "..reason) end
    local function applied(category,detail) result.applied[#result.applied+1]=category..": "..detail;log("apply","applied "..category..": "..detail) end
    local function failure(category,reason) result.errors[#result.errors+1]=category..": "..reason;log("error",category..": "..reason) end
    local hardBlocks={}
    local function hard(reason) hardBlocks[#hardBlocks+1]=reason end
    if not CONFIG.enableCrabSyncV2 then hard("CrabSyncV2 disabled") end
    if not CONFIG.allowApply then hard("apply disabled by config") end
    if CONFIG.dryRunApply then hard("dry-run mode") end
    if not CONFIG.backupBeforeApply then hard("backup required before every real apply") end
    if CONFIG.transportMode=="debug_loopback" then hard("debug loopback is diagnostics-only") end
    if CONFIG.transportMode=="p2p_carrier" then hard("carrier not ready: no approved candidate") end
    if CONFIG.healthMergePolicy=="sum_visible" or CONFIG.crystalMergePolicy=="sum_visible" or CONFIG.slotMergePolicy=="sum_visible" then hard("diagnostics-only sum_visible policy cannot authorize apply") end
    if runtime.lifecycleState~="stable" then hard("lifecycle instability: "..runtime.lifecycleState) end
    if not isValidUObject(playerState) then hard("invalid PlayerState") end
    if plan.lifecycleGeneration~=runtime.lifecycleGeneration or localSnapshot.lifecycleGeneration~=runtime.lifecycleGeneration or merged.lifecycleGeneration~=runtime.lifecycleGeneration then hard("lifecycle generation mismatch") end
    if plan.sessionId~=runtime.sessionId or localSnapshot.sessionId~=runtime.sessionId or merged.sessionId~=runtime.sessionId then hard("session fingerprint mismatch") end
    if plan.role=="unknown" then hard("role not allowed: unknown") end
    if plan.role=="joined-client" and not CONFIG.allowJoinedClientApply then hard("role not allowed: joined-client apply disabled") end
    if plan.role~="solo" and not CONFIG.allowMultiplayerApply then hard("role not allowed: multiplayer apply disabled") end
    if CONFIG.hostOnlyApply and plan.role~="solo" and plan.role~="host" then hard("role not allowed: host-only apply") end
    for _,reason in ipairs(plan.globalSkips or {}) do hard(reason) end
    if #hardBlocks>0 then for _,reason in ipairs(sortedUniqueStrings(hardBlocks)) do skip("global",reason) end;return result end
    if plan.changes==0 then skip("global","merged state already matches");return result end
    local path,reason=writeBackup(localSnapshot)
    if not path then failure("backup",reason);skip("global","backup required but failed");return result end
    result.backupPath=path

    if #plan.categories.health.actions>0 then
        if not CONFIG.allowHealthApply then skip("health","category disabled")
        elseif not CONFIG.allowRawPropertyWrites then skip("health","raw property writes disabled")
        else
            local info,err=safeGetProperty(playerState,"HealthInfo")
            if err or info==nil then failure("health",err or "HealthInfo unavailable")
            else
                local maxValue=math.max(0,tonumber(merged.health.currentMaxHealth) or 0)
                local currentValue=math.max(0,math.min(maxValue,tonumber(merged.health.currentHealth) or 0))
                local okMax,maxErr=safeSetStructField(info,"CurrentMaxHealth",maxValue)
                local okCurrent,currentErr=false,nil
                if okMax then okCurrent,currentErr=safeSetStructField(info,"CurrentHealth",currentValue) end
                if okMax and okCurrent then applied("health",formatNumber(currentValue).."/"..formatNumber(maxValue))
                else
                    if okMax then safeSetStructField(info,"CurrentMaxHealth",localSnapshot.health.currentMaxHealth) end
                    failure("health",tostring(maxErr or currentErr).."; max-health rollback attempted")
                end
            end
        end
    end

    if #plan.categories.equipment.actions>0 then
        if not CONFIG.allowEquipmentApply then skip("equipment","category disabled")
        elseif not CONFIG.allowOfficialFunctionApply then skip("equipment","official function candidate disabled")
        else
            local weapon,weaponErr=findDataAsset("CrabWeaponDA",merged.equipment.weapon)
            local ability,abilityErr=findDataAsset("CrabAbilityDA",merged.equipment.ability)
            local melee,meleeErr=findDataAsset("CrabMeleeDA",merged.equipment.melee)
            if not weapon or not ability or not melee then failure("equipment",weaponErr or abilityErr or meleeErr)
            else local _,callErr=safeCallFunction(playerState,"ServerEquipInventory",weapon,ability,melee);if callErr then failure("equipment",callErr) else applied("equipment","ServerEquipInventory") end end
        end
    end

    if #plan.categories.resources.actions>0 then
        if not CONFIG.allowResourceApply then skip("resources","category disabled")
        elseif not CONFIG.allowRawPropertyWrites then skip("resources","raw property writes disabled")
        else
            local crystalApplied=false
            for _,action in ipairs(plan.categories.resources.actions) do
                local property=nil;local value=action.to
                if action.kind=="crystal mismatch" then property="Crystals";value=clampInteger(value,0,UINT32_MAX)
                else property=({weaponMods="NumWeaponModSlots",abilityMods="NumAbilityModSlots",meleeMods="NumMeleeModSlots",perks="NumPerkSlots"})[action.field];value=clampInteger(value,0,BYTE_MAX) end
                local ok,err=safeSetProperty(playerState,property,value);if ok then applied("resources",property.."="..tostring(value));if property=="Crystals" then crystalApplied=true end else failure("resources",err) end
            end
            if crystalApplied and CONFIG.allowOnRepCrystals then local _,err=safeCallFunction(playerState,"OnRep_Crystals");if err then failure("refresh",err) else applied("refresh","OnRep_Crystals") end end
        end
    end

    local inventoryApplied=false
    if #plan.categories.inventory.actions>0 then
        if not CONFIG.allowInventoryApply then skip("inventory","category disabled")
        elseif plan.categories.inventory.multiplayerBlocked then skip("inventory","stable multiplayer origin/contribution ledger unavailable")
        elseif not CONFIG.allowMetadataApply and not CONFIG.allowEnhancementApply then skip("inventory","metadata and enhancement writes disabled")
        else
            local actionCategories={};for _,action in ipairs(plan.categories.inventory.actions) do actionCategories[action.category]=true end
            for _,category in ipairs(INVENTORY_CATEGORIES) do if actionCategories[category.key] then
                local targetItems=merged.inventory[category.key] or {}
                local liveSlots,liveErr=collectLiveSlots(playerState,category,localSnapshot)
                local liveItems={};for _,live in ipairs(liveSlots or {}) do liveItems[#liveItems+1]=live.item end
                local unknown,unknownReason=inventoryHasUnknown(targetItems)
                local liveUnknown,liveUnknownReason=inventoryHasUnknown(liveItems)
                local duplicate,duplicateIdentity=inventoryHasDuplicateIdentity(targetItems)
                local liveDuplicate,liveDuplicateIdentity=inventoryHasDuplicateIdentity(liveItems)
                local targetSupported=merged.inventory.categorySupported and merged.inventory.categorySupported[category.key]
                local liveSupported=localSnapshot.inventory.categorySupported and localSnapshot.inventory.categorySupported[category.key]
                if liveErr then failure(category.key,liveErr)
                elseif not targetSupported or not liveSupported then skip(category.key,"category completeness not proven")
                elseif #liveSlots~=#targetItems then skip(category.key,"unsafe item pairing: count mismatch/raw rebuild unsupported")
                elseif unknown then skip(category.key,"unsupported target field: "..unknownReason)
                elseif liveUnknown then skip(category.key,"backup unsafe: "..liveUnknownReason)
                elseif duplicate then skip(category.key,"duplicate ambiguity: "..duplicateIdentity)
                elseif liveDuplicate then skip(category.key,"local duplicate ambiguity: "..liveDuplicateIdentity)
                else
                    local targetsByIdentity={};local liveIdentities,targetIdentities={},{}
                    for _,target in ipairs(targetItems) do local identity=itemIdentity(target);targetsByIdentity[identity]=target;targetIdentities[#targetIdentities+1]=identity end
                    for _,live in ipairs(liveSlots) do liveIdentities[#liveIdentities+1]=itemIdentity(live.item) end
                    table.sort(liveIdentities);table.sort(targetIdentities)
                    if not arraysEqual(liveIdentities,targetIdentities) then
                        skip(category.key,"inventory item mismatch: identity replacement pairing unproven; raw array/DA rewrite blocked")
                    else
                        local categoryChanged=false;local categoryFailed=false
                        for _,live in ipairs(liveSlots) do
                            local target=targetsByIdentity[itemIdentity(live.item)]
                            local scalarChanged=live.item.level~=target.level or formatNumber(live.item.accumulatedBuff)~=formatNumber(target.accumulatedBuff)
                            local liveEnhancements,targetEnhancements={},{}
                            for _,value in ipairs(live.item.enhancements or {}) do liveEnhancements[#liveEnhancements+1]=tostring(value) end
                            for _,value in ipairs(target.enhancements or {}) do targetEnhancements[#targetEnhancements+1]=tostring(value) end
                            local enhancementChanged=not arraysEqual(liveEnhancements,targetEnhancements)
                            if scalarChanged and not CONFIG.allowMetadataApply then skip(category.key,"scalar metadata mismatch but metadata apply disabled");categoryFailed=true;break end
                            if enhancementChanged and not CONFIG.allowEnhancementApply then skip(category.key,"enhancement mismatch but enhancement apply disabled");categoryFailed=true;break end
                            if (scalarChanged or enhancementChanged) and live.info==nil then failure(category.key,"InventoryInfo unavailable");categoryFailed=true;break end
                            if scalarChanged then
                                local okLevel,levelErr=safeSetStructField(live.info,"Level",target.level)
                                local okAccum,accumErr=false,nil
                                if okLevel then okAccum,accumErr=safeSetStructField(live.info,"AccumulatedBuff",target.accumulatedBuff) end
                                if not okLevel or not okAccum then
                                    if okLevel then safeSetStructField(live.info,"Level",live.item.level) end
                                    failure(category.key,(levelErr or accumErr).."; scalar rollback attempted");categoryFailed=true;break
                                end
                            end
                            if enhancementChanged then
                                local okEnhancement,enhancementErr=writeEnhancements(live.info,target.enhancements)
                                if not okEnhancement then
                                    if scalarChanged then safeSetStructField(live.info,"Level",live.item.level);safeSetStructField(live.info,"AccumulatedBuff",live.item.accumulatedBuff) end
                                    failure(category.key,enhancementErr.."; scalar rollback attempted");categoryFailed=true;break
                                end
                            end
                            if scalarChanged or enhancementChanged then
                                categoryChanged=true;inventoryApplied=true
                                applied(category.key,"full-identity metadata/enhancement pairing identity="..itemIdentity(live.item))
                            end
                        end
                        if categoryChanged and categoryFailed then skip(category.key,"partial category apply recorded; use backup for manual recovery") end
                    end
                end
            end end
            if inventoryApplied and CONFIG.allowOnRepInventory then local _,err=safeCallFunction(playerState,"OnRep_Inventory");if err then failure("refresh",err) else applied("refresh","OnRep_Inventory") end end
        end
    end
    if #result.applied>0 and CONFIG.allowClientRefreshPSUI then
        local pc=getLocalPlayerState();local _,err=safeCallFunction(pc,"ClientRefreshPSUI");if err then failure("refresh",err) else applied("refresh","ClientRefreshPSUI") end
    end
    log("apply",string.format("result applied=%d skipped=%d errors=%d backup=%s",#result.applied,#result.skipped,#result.errors,tostring(result.backupPath or "none")))
    return result
end

API.writeBackup=writeBackup
API.executeApplyPlan=executeApplyPlan

-- --------------------------------------------------------------------------
-- Pasteable diagnostics, lifecycle loop, and manual restore helpers
-- --------------------------------------------------------------------------

local function jsonEscape(value)
    return tostring(value or "")
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\b", "\\b")
        :gsub("\f", "\\f")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
end

local function jsonEncode(value)
    local seen={}
    local function encode(current,depth)
        if depth>24 then return '"<max-depth>"' end
        local kind=type(current)
        if kind=="nil" then return "null" end
        if kind=="boolean" then return current and "true" or "false" end
        if kind=="number" then return isFinite(current) and formatNumber(current) or "null" end
        if kind=="string" then return '"'..jsonEscape(current)..'"' end
        if kind~="table" then return '"<'..jsonEscape(kind)..'>"' end
        if seen[current] then return '"<cycle>"' end
        seen[current]=true
        local count,maxIndex,isArray=0,0,true
        for key,_ in pairs(current) do
            count=count+1
            if type(key)~="number" or key<1 or key~=math.floor(key) then isArray=false
            elseif key>maxIndex then maxIndex=key end
        end
        local parts={}
        if isArray and maxIndex==count then
            for index=1,count do parts[#parts+1]=encode(current[index],depth+1) end
            seen[current]=nil
            return "["..table.concat(parts,",").."]"
        end
        local keys={}
        for key,_ in pairs(current) do keys[#keys+1]=tostring(key) end
        table.sort(keys)
        for _,key in ipairs(keys) do parts[#parts+1]='"'..jsonEscape(key)..'":'..encode(current[key],depth+1) end
        seen[current]=nil
        return "{"..table.concat(parts,",").."}"
    end
    return encode(value,0)
end

local function initializeRuntimeIdentity()
    if runtime.clientInstanceId~="" then return end
    local seed=tostring(os.time() or 0).."|"..tostring({})
    local hash=fingerprintValue(seed)
    runtime.clientInstanceId="cs2-"..tostring(hash)
    runtime.diagnosticsPath=SCRIPT_DIR.."diagnostics_"..runtime.clientInstanceId..".jsonl"
end

local function recordDiagnostics(event,payload)
    initializeRuntimeIdentity()
    local entry={
        timestampMs=nowMs(),event=tostring(event),buildVersion=BUILD_VERSION,
        protocolVersion=PROTOCOL_VERSION,sessionId=runtime.sessionId,
        clientInstanceId=runtime.clientInstanceId,role=runtime.localRole,
        lifecycleState=runtime.lifecycleState,
        lifecycleGeneration=runtime.lifecycleGeneration,
        tick=runtime.tick,payload=payload,
    }
    local encoded=jsonEncode(entry)
    local file,reason=io.open(runtime.diagnosticsPath,"ab")
    if not file then
        runtime.lastError="diagnostics open failed: "..tostring(reason)
        log("error",runtime.lastError)
        return false,runtime.lastError
    end
    local ok,writeReason=pcall(function() file:write(encoded.."\n");file:close() end)
    if not ok then
        pcall(function() file:close() end)
        runtime.lastError="diagnostics write failed: "..tostring(writeReason)
        log("error",runtime.lastError)
        return false,runtime.lastError
    end
    return true,nil
end

local function lifecycleProbe()
    local pc,playerState,reason=getLocalPlayerState()
    if not playerState then
        if runtime.lifecycleState~="suspended" then
            runtime.lifecycleGeneration=runtime.lifecycleGeneration+1
            log("lifecycle","suspended reason="..tostring(reason))
        end
        runtime.lifecycleState="suspended"
        runtime.stableTicks=0
        runtime.lastLifecycleSignature=""
        runtime.localPlayerState=nil
        runtime.localRole="unknown"
        return nil,reason
    end

    local peers=discoverPeers()
    local role=detectRole(pc,playerState,peers)
    local sessionId=computeSessionId(peers)
    local pawn=safeGetProperty(pc,"Pawn")
    local signature=tostring(playerState).."|"..tostring(pawn).."|"..role.."|"..sessionId
    if signature~=runtime.lastLifecycleSignature then
        runtime.lifecycleGeneration=runtime.lifecycleGeneration+1
        runtime.stableTicks=1
        runtime.lastLifecycleSignature=signature
        runtime.lifecycleState="probing"
        log("lifecycle",string.format("new generation=%d role=%s session=%s",runtime.lifecycleGeneration,role,sessionId))
    else
        runtime.stableTicks=math.min(CONFIG.stableTicksRequired,runtime.stableTicks+1)
        runtime.lifecycleState=(runtime.stableTicks>=CONFIG.stableTicksRequired) and "stable" or "probing"
    end
    runtime.localPlayerState=playerState
    runtime.localRole=role
    runtime.sessionId=sessionId
    return {pc=pc,playerState=playerState,peers=peers,role=role,sessionId=sessionId,stable=(runtime.lifecycleState=="stable")},nil
end

local function findLocalPeer(peers,playerState)
    for _,peer in ipairs(peers or {}) do if sameObject(peer.object,playerState) then return peer end end
    return nil
end

local function runSyncTick()
    runtime.tick=clampInteger(runtime.tick+1,0,UINT32_MAX)
    breadcrumb("poll","enter")
    local context,lifecycleReason=lifecycleProbe()
    if not context or not context.stable then
        if runtime.tick==1 or runtime.tick%10==0 then
            log("lifecycle",string.format("state=%s stableTicks=%d/%d reason=%s",runtime.lifecycleState,runtime.stableTicks,CONFIG.stableTicksRequired,tostring(lifecycleReason or "warming")))
        end
        recordDiagnostics("lifecycle",{reason=lifecycleReason or "warming",stableTicks=runtime.stableTicks,required=CONFIG.stableTicksRequired})
        breadcrumb("poll","leave unstable")
        return nil,"lifecycle not stable"
    end
    if context.role=="unknown" then
        recordDiagnostics("lifecycle",{reason="role unresolved; snapshot work suspended"})
        breadcrumb("poll","leave unknown role")
        return nil,"role unresolved"
    end

    local localPeer=findLocalPeer(context.peers,context.playerState)
    if not localPeer then
        recordDiagnostics("error",{phase="local-peer",reason="local PlayerState missing from peer set"})
        breadcrumb("poll","leave local peer missing")
        return nil,"local peer unavailable"
    end

    local localSnapshot,localReason=buildVisibleSnapshot(localPeer,context.playerState,context.role,context.sessionId)
    if not localSnapshot then
        recordDiagnostics("error",{phase="local-snapshot",reason=localReason})
        breadcrumb("poll","leave local snapshot failed")
        return nil,localReason
    end
    runtime.lastSnapshot=localSnapshot

    if CONFIG.allowCarrierDiscovery then discoverCarrierCandidates(context.peers) end
    if CONFIG.transportMode=="debug_loopback" then
        local published,publishReason=publishSnapshot(localSnapshot)
        log("transport",string.format("debug loopback publish=%s reason=%s",tostring(published),tostring(publishReason or "ok")))
    elseif CONFIG.transportMode=="game_visible" or CONFIG.transportMode=="p2p_carrier" then
        local published,publishReason=publishSnapshot(localSnapshot)
        if not published then log("transport","publish skipped: "..tostring(publishReason)) end
    end

    local rows,transportReason=readPeerSnapshots(context.peers,context.playerState,context.role,context.sessionId)
    if transportReason then log("transport",transportReason) end
    if CONFIG.transportMode=="disabled" and #rows==0 then rows={localSnapshot} end

    local merged,mergeReport=mergeSnapshots(rows,nowMs(),context.sessionId,runtime.lifecycleGeneration)
    if not merged then
        recordDiagnostics("merge",{status="no-accepted-rows",report=mergeReport,transportReason=transportReason})
        breadcrumb("poll","leave merge empty")
        return nil,"no accepted peer snapshots"
    end
    runtime.lastMerged=merged
    log("merge",string.format("accepted=%d rejected=%d health=%s equipment=%s resources=%s inventory=%s",mergeReport.accepted,#mergeReport.rejected,tostring(merged.health.supported),tostring(merged.equipment.supported),tostring(merged.resources.supported),tostring(merged.inventory.supported)))
    for _,rejected in ipairs(mergeReport.rejected) do log("merge","rejected index="..tostring(rejected.index).." reason="..tostring(rejected.reason)) end

    local plan=buildApplyPlan(localSnapshot,merged,context,mergeReport)
    local result=executeApplyPlan(context.playerState,localSnapshot,merged,plan)
    local diagnosticPayload={
        status="ok",peerCount=#context.peers,rowCount=#rows,
        visiblePeerSnapshots=rows,
        mergeReport=mergeReport,applyPlan=plan,applyResult=result,
        lastBackupPath=runtime.lastBackupPath,
    }
    if runtime.lastCarrierCandidates then diagnosticPayload.carrierCandidates=runtime.lastCarrierCandidates end
    if CONFIG.debugVerboseSnapshots then
        diagnosticPayload.localSnapshot=localSnapshot
        diagnosticPayload.mergedSnapshot=merged
        diagnosticPayload.carrierCandidates=runtime.lastCarrierCandidates
    end
    recordDiagnostics("sync-tick",diagnosticPayload)
    breadcrumb("poll","leave ok")
    return {localSnapshot=localSnapshot,mergedSnapshot=merged,mergeReport=mergeReport,applyPlan=plan,applyResult=result},nil
end

local pollTick
local function scheduleNextTick()
    if type(ExecuteWithDelay)=="function" and CONFIG.enableCrabSyncV2 then
        ExecuteWithDelay(CONFIG.pollIntervalMs,function() pollTick() end)
    end
end

pollTick=function()
    local ok,result,reason=pcall(runSyncTick)
    if not ok then
        runtime.lastError=tostring(result)
        log("error","poll crashed: "..runtime.lastError)
        recordDiagnostics("error",{phase="poll",reason=runtime.lastError})
    elseif not result and reason and runtime.tick%10==0 then
        log("poll","skipped: "..tostring(reason))
    end
    scheduleNextTick()
end

local function readBackup(path)
    local file,openReason=io.open(tostring(path or ""),"rb")
    if not file then return nil,"backup open failed: "..tostring(openReason) end
    local ok,contents=pcall(function() local value=file:read("*a");file:close();return value end)
    if not ok then pcall(function() file:close() end);return nil,"backup read failed: "..tostring(contents) end
    return decodeSnapshot(contents)
end

local function restoreBackup(path)
    local target,readReason=readBackup(path)
    if not target then log("restore",readReason);return nil,readReason end
    local context,lifecycleReason=lifecycleProbe()
    if not context or not context.stable then return nil,"restore blocked: "..tostring(lifecycleReason or runtime.lifecycleState) end
    local localPeer=findLocalPeer(context.peers,context.playerState)
    if not localPeer then return nil,"restore blocked: local peer unavailable" end
    local current,currentReason=buildVisibleSnapshot(localPeer,context.playerState,context.role,context.sessionId)
    if not current then return nil,currentReason end
    -- Manual restore is explicit, but it still uses the current lifecycle/session
    -- and every normal apply/dry-run/category gate.
    target.sessionId=context.sessionId
    target.timestampMs=nowMs()
    target.lifecycleGeneration=runtime.lifecycleGeneration
    target.transportMode="debug_loopback"
    local plan=buildApplyPlan(current,target,context,{accepted=1,rejected={}})
    local result=executeApplyPlan(context.playerState,current,target,plan)
    recordDiagnostics("manual-restore",{path=path,applyPlan=plan,applyResult=result})
    log("restore",string.format("path=%s applied=%d skipped=%d errors=%d",tostring(path),#result.applied,#result.skipped,#result.errors))
    return {target=target,plan=plan,result=result},nil
end

API.tick=runSyncTick
API.forcePoll=runSyncTick
API.restoreBackup=restoreBackup
API.readBackup=readBackup
API.recordDiagnostics=recordDiagnostics
API.getLastBackupPath=function() return runtime.lastBackupPath end
API.getRuntimeState=function()
    return {
        version=BUILD_VERSION,protocolVersion=PROTOCOL_VERSION,
        lifecycleState=runtime.lifecycleState,lifecycleGeneration=runtime.lifecycleGeneration,
        stableTicks=runtime.stableTicks,role=runtime.localRole,sessionId=runtime.sessionId,
        tick=runtime.tick,diagnosticsPath=runtime.diagnosticsPath,
        lastBackupPath=runtime.lastBackupPath,lastError=runtime.lastError,
        lastSnapshot=deepCopy(runtime.lastSnapshot),lastMerged=deepCopy(runtime.lastMerged),
        lastPlan=deepCopy(runtime.lastPlan),carrierCandidates=deepCopy(runtime.lastCarrierCandidates),
    }
end
API.setDebugLoopbackSnapshots=function(rows)
    if not CONFIG.allowDebugLoopbackTransport then return false,"debug loopback disabled" end
    runtime.loopbackRows=deepCopy(type(rows)=="table" and rows or {})
    runtime.loopbackInjected=true
    return true,nil
end

initializeRuntimeIdentity()
loadConfig()
log("startup",string.format("loaded %s protocol=%d instance=%s diagnostics=%s",BUILD_VERSION,PROTOCOL_VERSION,runtime.clientInstanceId,runtime.diagnosticsPath))
if not CONFIG.enableCrabSyncV2 then
    runtime.lifecycleState="disabled"
    log("startup","CrabSyncV2 disabled by safe default; set enableCrabSyncV2=true and restart to test")
else
    runtime.lifecycleState="probing"
    recordDiagnostics("startup",{
        warning="experimental private-test build; not production-safe",
        transportMode=CONFIG.transportMode,dryRunApply=CONFIG.dryRunApply,
        carrierReady=false,keysExcluded=true,armorApply=false,
        config=deepCopy(CONFIG),diagnosticsPath=runtime.diagnosticsPath,
    })
    if type(ExecuteWithDelay)=="function" then
        ExecuteWithDelay(CONFIG.pollIntervalMs,function() pollTick() end)
    else
        log("startup","ExecuteWithDelay unavailable; running one synchronous diagnostic tick")
        pollTick()
    end
end
