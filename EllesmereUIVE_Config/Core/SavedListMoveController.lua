local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.SavedListMoveController = NS.SavedListMoveController or {}
local MoveController = NS.SavedListMoveController

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end
local MoveContext = NS.SavedListMoveContext or {}
local DropKey = NS.SavedListDropKey or {}

local function TrimText(value)
    return MoveContext:TrimText(value)
end

local function NormalizeIconID(value)
    return MoveContext:NormalizeIconID(value)
end

local function GetApi()
    return MoveContext:GetApi()
end

local function RequestNativeUIRefresh(reason)
    return MoveContext:RequestNativeUIRefresh(reason)
end

local function IsLoadedScope(api, classID, specID, currentClassID, currentSpecID)
    return MoveContext:IsLoadedScope(api, classID, specID, currentClassID, currentSpecID)
end

local function EnsureRootDB()
    return MoveContext:EnsureRootDB()
end

local function BuildEntryKey(classID, specID, index)
    return MoveContext:BuildEntryKey(classID, specID, index)
end

local function ParseEntryKey(key)
    return MoveContext:ParseEntryKey(key)
end

local function BuildGroupKey(classID, specID, groupID)
    return MoveContext:BuildGroupKey(classID, specID, groupID)
end

local function ParseGroupKey(key)
    return MoveContext:ParseGroupKey(key)
end

local function ParseRootKey(key)
    if DropKey and type(DropKey.ParseRootKey) == "function" then
        return DropKey:ParseRootKey(key)
    end
    local classID, specID = tostring(key or ""):match("^root:(%-?%d+):(%-?%d+)$")
    return tonumber(classID) or -1, tonumber(specID) or -1
end

local function EntryRefToKey(scopeClassID, scopeSpecID, ref)
    return MoveContext:EntryRefToKey(scopeClassID, scopeSpecID, ref)
end

local function IsSameScopeGroupRef(scopeClassID, scopeSpecID, ref)
    return MoveContext:IsSameScopeGroupRef(scopeClassID, scopeSpecID, ref)
end

local function EnsureCollectionScope(classID, specID)
    return MoveContext:EnsureCollectionScope(classID, specID)
end

local function NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID)
    return MoveContext:NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID)
end

local function RemoveEntryKeyFromCollectionScope(scope, entryKey, scopeClassID, scopeSpecID)
    return MoveContext:RemoveEntryKeyFromCollectionScope(scope, entryKey, scopeClassID, scopeSpecID)
end

local function RemoveGroupKeyFromCollectionScope(scope, groupKey, scopeClassID, scopeSpecID)
    return MoveContext:RemoveGroupKeyFromCollectionScope(scope, groupKey, scopeClassID, scopeSpecID)
end

local function FindGroupKeyLocation(scope, groupKey, scopeClassID, scopeSpecID)
    return MoveContext:FindGroupKeyLocation(scope, groupKey, scopeClassID, scopeSpecID)
end

local function GroupContainsGroup(scope, parentGroupID, childGroupID, scopeClassID, scopeSpecID, seen)
    return MoveContext:GroupContainsGroup(scope, parentGroupID, childGroupID, scopeClassID, scopeSpecID, seen)
end

local function InsertGroupIntoRoot(scope, groupID, position)
    return MoveContext:InsertGroupIntoRoot(scope, groupID, position)
end

local function InsertGroupIntoGroup(scope, parentGroupID, childGroupKey, position)
    return MoveContext:InsertGroupIntoGroup(scope, parentGroupID, childGroupKey, position)
end

local function RemoveEntryKeyFromAllCollectionScopes(entryKey)
    return MoveContext:RemoveEntryKeyFromAllCollectionScopes(entryKey)
end

local function RecordSavedListDisplayMove(sourceKey, targetKey, targetSection, insertAfter)
    return MoveContext:RecordSavedListDisplayMove(sourceKey, targetKey, targetSection, insertAfter)
end

local function FindEntryKeyLocation(scope, entryKey, scopeClassID, scopeSpecID)
    local key, classID, specID, index = EntryRefToKey(scopeClassID, scopeSpecID, entryKey)
    if type(scope) ~= "table" or not key or index <= 0 then
        return nil
    end

    if classID == tonumber(scopeClassID) and specID == tonumber(scopeSpecID) then
        for i, item in ipairs(scope.root or {}) do
            if type(item) == "table" and item.type == "entry" and tonumber(item.index) == index then
                return { container = "root", position = i }
            end
        end
    end

    for groupID, group in pairs(scope.groups or {}) do
        if type(group) == "table" and type(group.entries) == "table" then
            for i, value in ipairs(group.entries) do
                local groupEntryKey = EntryRefToKey(scopeClassID, scopeSpecID, value)
                if groupEntryKey == key then
                    return { container = "group", groupID = tostring(groupID), position = i }
                end
            end
        end
    end
    return nil
end

local function InsertEntryKeyAtCollectionLocation(scope, sourceEntryKey, sourceIndex, loc, insertAfter, sameScope)
    if type(scope) ~= "table" or not loc then
        return false
    end
    local pos = math.max(1, (tonumber(loc.position) or 1) + (insertAfter and 1 or 0))

    if loc.container == "group" and loc.groupID and type(scope.groups) == "table" then
        local group = scope.groups[tostring(loc.groupID or "")]
        if type(group) ~= "table" then
            return false
        end
        if type(group.entries) ~= "table" then
            group.entries = {}
        end
        table.insert(group.entries, math.min(pos, #group.entries + 1), tostring(sourceEntryKey or ""))
        return true
    end

    if loc.container == "root" then
        -- Root entries are stored as local indexes, so only same-scope entries can
        -- be inserted into a scope root. Cross-scope display-only ordering is handled
        -- by SavedListOrder instead.
        if not sameScope then
            return false
        end
        if type(scope.root) ~= "table" then
            scope.root = {}
        end
        sourceIndex = tonumber(sourceIndex) or 0
        if sourceIndex <= 0 then
            return false
        end
        table.insert(scope.root, math.min(pos, #scope.root + 1), { type = "entry", index = sourceIndex })
        return true
    end

    return false
end

function MoveController:MoveSavedListItem(aceOptions, sourceKey, targetKey, targetSection, suppressRefresh)
    aceOptions = aceOptions or NS.AceOptions or {}
    local api = GetApi()
    if not api then
        return false
    end
    sourceKey = tostring(sourceKey or "")
    targetKey = tostring(targetKey or "")
    local targetInfo
    if DropKey and type(DropKey.Split) == "function" then
        targetInfo = DropKey:Split(targetKey)
    else
        local cleanTarget = targetKey
        local mode = "before"
        if cleanTarget:match(":inside$") then
            cleanTarget = cleanTarget:gsub(":inside$", "")
            mode = "inside"
        elseif cleanTarget:match(":after$") then
            cleanTarget = cleanTarget:gsub(":after$", "")
            mode = "after"
        end
        cleanTarget = cleanTarget:gsub(":empty$", "")
        targetInfo = { key = cleanTarget, mode = mode, isInside = mode == "inside", isAfter = mode == "after" }
    end

    local insertAfter = targetInfo.isAfter == true
    local insertInside = targetInfo.isInside == true
    local displayTargetSection = tostring(targetSection or "")
    targetKey = tostring(targetInfo.key or "")
    if sourceKey == "" or targetKey == "" or sourceKey == targetKey then
        return false
    end

    local currentClassID, currentSpecID = api.GetCurrentClassSpec()
    if currentClassID <= 0 or currentSpecID <= 0 then
        return false
    end

    local currentScope = EnsureCollectionScope(currentClassID, currentSpecID)
    NormalizeCollectionScope(currentScope, api.GetStoredEntryMap(currentClassID, currentSpecID), currentClassID, currentSpecID)

    local sourceIsGroup = sourceKey:match("^group:") ~= nil
    local targetIsGroup = targetKey:match("^group:") ~= nil
    local targetIsRoot = targetKey:match("^root:") ~= nil

    if sourceIsGroup then
        local sourceClassID, sourceSpecID, sourceGroupID = ParseGroupKey(sourceKey)
        if sourceClassID < 0 or sourceSpecID < 0 or sourceGroupID == "" then
            return false
        end

        local sourceScope = EnsureCollectionScope(sourceClassID, sourceSpecID)
        if not sourceScope or type(sourceScope.groups[sourceGroupID]) ~= "table" then
            return false
        end
        NormalizeCollectionScope(sourceScope, api.GetStoredEntryMap(sourceClassID, sourceSpecID), sourceClassID, sourceSpecID)

        local function insertSourceAtLocation(loc, fallbackRootPosition)
            -- 鍏堥獙璇佺洰鏍囷紝鍐嶇Щ闄ゅ師浣嶇疆銆傚惁鍒欐妸鐖跺悎闆嗘嫋鍒拌嚜宸辩殑瀛愬悎闆?闈炴硶鐩爣鏃讹紝
            -- 浼氬厛浠庡師浣嶇疆绉婚櫎锛屽鑷村悎闆嗏€滄秷澶扁€濄€?
            local originalLoc = FindGroupKeyLocation(sourceScope, sourceKey, sourceClassID, sourceSpecID)

            if loc and loc.container == "group" and loc.groupID and type(sourceScope.groups[loc.groupID]) == "table" then
                if loc.groupID == sourceGroupID or GroupContainsGroup(sourceScope, sourceGroupID, loc.groupID, sourceClassID, sourceSpecID) then
                    return false
                end
                RemoveGroupKeyFromCollectionScope(sourceScope, sourceKey, sourceClassID, sourceSpecID)
                local pos = math.max(1, (tonumber(loc.position) or 1) + (insertAfter and 1 or 0))
                if InsertGroupIntoGroup(sourceScope, loc.groupID, sourceKey, pos) then
                    return true
                end
            else
                RemoveGroupKeyFromCollectionScope(sourceScope, sourceKey, sourceClassID, sourceSpecID)
                local pos = fallbackRootPosition or (loc and loc.position) or (#(sourceScope.root or {}) + 1)
                if insertAfter then
                    pos = pos + 1
                end
                if InsertGroupIntoRoot(sourceScope, sourceGroupID, pos) then
                    return true
                end
            end

            -- 鏋佺鎯呭喌涓嬟彃鍏ュけ璐ワ紝鎭㈠鍒板師浣嶇疆锛岄伩鍏嶄繚瀛樼粨鏋勪涪澶便€?
            if originalLoc and originalLoc.container == "group" and originalLoc.groupID and type(sourceScope.groups[originalLoc.groupID]) == "table" then
                InsertGroupIntoGroup(sourceScope, originalLoc.groupID, sourceKey, originalLoc.position)
            elseif originalLoc and originalLoc.container == "root" then
                InsertGroupIntoRoot(sourceScope, sourceGroupID, originalLoc.position)
            else
                InsertGroupIntoRoot(sourceScope, sourceGroupID)
            end
            return false
        end

        local moved = false
        local function moveGroupTreeAcrossScope(targetClassID, targetSpecID, targetLoc, targetGroupIDForInside)
            targetClassID = tonumber(targetClassID) or 0
            targetSpecID = tonumber(targetSpecID) or 0
            if targetClassID < 0 or targetSpecID < 0 then
                return false
            end
            if targetClassID == sourceClassID and targetSpecID == sourceSpecID then
                return false
            end

            local targetScope = EnsureCollectionScope(targetClassID, targetSpecID)
            if not targetScope then
                return false
            end
            NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)

            local db = EnsureRootDB()
            local idMap = {}
            local movedIDs = {}

            local function allocateGroupID()
                db.collectionSerial = (tonumber(db.collectionSerial) or 0) + 1
                return "g" .. tostring(db.collectionSerial)
            end

            local function cloneGroup(oldID, seen)
                oldID = tostring(oldID or "")
                if oldID == "" or type(sourceScope.groups[oldID]) ~= "table" then
                    return nil
                end
                if idMap[oldID] then
                    return idMap[oldID]
                end
                seen = seen or {}
                if seen[oldID] then
                    return nil
                end
                seen[oldID] = true

                local oldGroup = sourceScope.groups[oldID]
                local newID = allocateGroupID()
                idMap[oldID] = newID
                movedIDs[oldID] = true

                local newEntries = {}
                targetScope.groups[newID] = {
                    name = TrimText(oldGroup.name) ~= "" and TrimText(oldGroup.name) or L("COLLECTION_UNNAMED"),
                    iconID = NormalizeIconID(oldGroup.iconID),
                    collapsed = oldGroup.collapsed == true,
                    entries = newEntries,
                }

                for _, ref in ipairs(oldGroup.entries or {}) do
                    local _, childGroupID = IsSameScopeGroupRef(sourceClassID, sourceSpecID, ref)
                    if childGroupID and type(sourceScope.groups[childGroupID]) == "table" then
                        local childNewID = cloneGroup(childGroupID, seen)
                        if childNewID then
                            newEntries[#newEntries + 1] = BuildGroupKey(targetClassID, targetSpecID, childNewID)
                        end
                    else
                        local entryKey = EntryRefToKey(sourceClassID, sourceSpecID, ref)
                        if entryKey then
                            newEntries[#newEntries + 1] = entryKey
                        end
                    end
                end

                seen[oldID] = nil
                return newID
            end

            local newGroupID = cloneGroup(sourceGroupID, {})
            if not newGroupID then
                return false
            end
            local newGroupKey = BuildGroupKey(targetClassID, targetSpecID, newGroupID)

            for oldID in pairs(movedIDs) do
                RemoveGroupKeyFromCollectionScope(sourceScope, BuildGroupKey(sourceClassID, sourceSpecID, oldID), sourceClassID, sourceSpecID)
            end
            for oldID in pairs(movedIDs) do
                sourceScope.groups[oldID] = nil
            end

            local ok = false
            if targetGroupIDForInside and type(targetScope.groups[targetGroupIDForInside]) == "table" then
                ok = InsertGroupIntoGroup(targetScope, targetGroupIDForInside, newGroupKey)
            elseif targetLoc and targetLoc.container == "group" and targetLoc.groupID and type(targetScope.groups[targetLoc.groupID]) == "table" then
                local pos = math.max(1, (tonumber(targetLoc.position) or 1) + (insertAfter and 1 or 0))
                ok = InsertGroupIntoGroup(targetScope, targetLoc.groupID, newGroupKey, pos)
            else
                local pos = (targetLoc and targetLoc.position) or (#(targetScope.root or {}) + 1)
                if insertAfter then
                    pos = pos + 1
                end
                ok = InsertGroupIntoRoot(targetScope, newGroupID, pos)
            end

            NormalizeCollectionScope(sourceScope, api.GetStoredEntryMap(sourceClassID, sourceSpecID), sourceClassID, sourceSpecID)
            NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
            if ok then
                sourceKey = newGroupKey
            end
            return ok
        end

        if targetIsRoot then
            local targetClassID, targetSpecID = ParseRootKey(targetKey)
            if targetClassID == sourceClassID and targetSpecID == sourceSpecID then
                moved = insertSourceAtLocation(nil, #(sourceScope.root or {}) + 1)
            else
                moved = moveGroupTreeAcrossScope(targetClassID, targetSpecID, nil, nil)
            end
        elseif targetIsGroup then
            local targetClassID, targetSpecID, targetGroupID = ParseGroupKey(targetKey)
            if targetGroupID == "" then
                return false
            end
            if targetClassID == sourceClassID and targetSpecID == sourceSpecID then
                if type(sourceScope.groups[targetGroupID]) ~= "table" then
                    return false
                end
                if targetGroupID == sourceGroupID or GroupContainsGroup(sourceScope, sourceGroupID, targetGroupID, sourceClassID, sourceSpecID) then
                    return false
                end

                if insertInside then
                    RemoveGroupKeyFromCollectionScope(sourceScope, sourceKey, sourceClassID, sourceSpecID)
                    moved = InsertGroupIntoGroup(sourceScope, targetGroupID, sourceKey)
                else
                    local targetLoc = FindGroupKeyLocation(sourceScope, targetKey, sourceClassID, sourceSpecID)
                    moved = insertSourceAtLocation(targetLoc)
                end
            else
                local targetScope = EnsureCollectionScope(targetClassID, targetSpecID)
                if not targetScope then
                    return false
                end
                NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
                if type(targetScope.groups[targetGroupID]) ~= "table" then
                    return false
                end
                if insertInside then
                    moved = moveGroupTreeAcrossScope(targetClassID, targetSpecID, nil, targetGroupID)
                else
                    local targetLoc = FindGroupKeyLocation(targetScope, targetKey, targetClassID, targetSpecID)
                    if targetLoc and targetLoc.container == "group" then
                        moved = moveGroupTreeAcrossScope(targetClassID, targetSpecID, targetLoc, nil)
                    else
                        RecordSavedListDisplayMove(sourceKey, targetKey, displayTargetSection, insertAfter)
                        moved = true
                    end
                end
            end
        else
            local targetClassID, targetSpecID, targetIndex = ParseEntryKey(targetKey)
            if targetIndex <= 0 then
                return false
            end

            if targetClassID == sourceClassID and targetSpecID == sourceSpecID then
                local targetEntryKey = BuildEntryKey(targetClassID, targetSpecID, targetIndex)
                local targetLoc = FindEntryKeyLocation(sourceScope, targetEntryKey, targetClassID, targetSpecID)
                moved = insertSourceAtLocation(targetLoc)
            else
                local targetScope = EnsureCollectionScope(targetClassID, targetSpecID)
                if not targetScope then
                    return false
                end
                NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
                local targetEntryKey = BuildEntryKey(targetClassID, targetSpecID, targetIndex)
                local targetLoc = FindEntryKeyLocation(targetScope, targetEntryKey, targetClassID, targetSpecID)
                if targetLoc and targetLoc.container == "group" then
                    moved = moveGroupTreeAcrossScope(targetClassID, targetSpecID, targetLoc, nil)
                else
                    RecordSavedListDisplayMove(sourceKey, targetKey, displayTargetSection, insertAfter)
                    moved = true
                end
            end
        end

        if not moved then
            return false
        end

        NormalizeCollectionScope(sourceScope, api.GetStoredEntryMap(sourceClassID, sourceSpecID), sourceClassID, sourceSpecID)
        local state = aceOptions:GetState()
        state.selectedKey = sourceKey
        state.selectedCollectionKey = sourceKey
    else
        local sourceClassID, sourceSpecID, sourceIndex = ParseEntryKey(sourceKey)
        if sourceClassID < 0 or sourceSpecID < 0 or sourceIndex <= 0 then
            return false
        end

        local sourceEntryKey = BuildEntryKey(sourceClassID, sourceSpecID, sourceIndex)
        local sourceIsLoaded = IsLoadedScope(api, sourceClassID, sourceSpecID, currentClassID, currentSpecID)
        local sourceWasInCurrentScope = FindEntryKeyLocation(currentScope, sourceEntryKey, currentClassID, currentSpecID) ~= nil

        if targetIsRoot then
            local targetClassID, targetSpecID = ParseRootKey(targetKey)
            local targetScope = EnsureCollectionScope(targetClassID, targetSpecID)
            if not targetScope then
                return false
            end
            NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
            local sameScope = sourceClassID == targetClassID and sourceSpecID == targetSpecID
            if sameScope then
                while RemoveEntryKeyFromCollectionScope(targetScope, sourceEntryKey, targetClassID, targetSpecID) do end
                if type(targetScope.root) ~= "table" then
                    targetScope.root = {}
                end
                targetScope.root[#targetScope.root + 1] = { type = "entry", index = sourceIndex }
                NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
            else
                RemoveEntryKeyFromAllCollectionScopes(sourceEntryKey)
                RecordSavedListDisplayMove(sourceEntryKey, targetKey, displayTargetSection, true)
            end
        elseif targetIsGroup then
            local targetClassID, targetSpecID, targetGroupID = ParseGroupKey(targetKey)
            local targetScope = EnsureCollectionScope(targetClassID, targetSpecID)
            if not targetScope then
                return false
            end
            NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
            if type(targetScope.groups[tostring(targetGroupID or "")]) ~= "table" then
                print("[EUIVE] " .. L("MSG_UNLOADED_ONLY_TO_LOADED_GROUP"))
                return false
            end
        elseif not sourceIsLoaded then
            local targetClassID, targetSpecID, targetIndex = ParseEntryKey(targetKey)
            local targetScope = EnsureCollectionScope(targetClassID, targetSpecID)
            if not targetScope then
                return false
            end
            NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
            local targetEntryKey = BuildEntryKey(targetClassID, targetSpecID, targetIndex)
            local loc = FindEntryKeyLocation(targetScope, targetEntryKey, targetClassID, targetSpecID)
            if not (loc and loc.container == "group") and displayTargetSection ~= "unloaded" then
                print("[EUIVE] " .. L("MSG_DRAG_UNLOADED_TO_ROOT"))
                return false
            end
        end

        if targetIsRoot then
            -- Already moved to the target root above.
        elseif targetIsGroup then
            local targetClassID, targetSpecID, targetGroupID = ParseGroupKey(targetKey)
            local targetScope = EnsureCollectionScope(targetClassID, targetSpecID)
            if not targetScope then
                return false
            end
            NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
            local group = targetScope.groups[tostring(targetGroupID or "")]
            if type(group) ~= "table" then
                return false
            end

            local sameScope = sourceClassID == targetClassID and sourceSpecID == targetSpecID

            if insertInside then
                -- Same-scope moves only need to clean the current collection scope.
                -- Avoid scanning every class/spec when dropping an entry into a group.
                if sameScope then
                    while RemoveEntryKeyFromCollectionScope(targetScope, sourceEntryKey, targetClassID, targetSpecID) do end
                else
                    RemoveEntryKeyFromAllCollectionScopes(sourceEntryKey)
                end

                if type(group.entries) ~= "table" then
                    group.entries = {}
                end
                group.entries[#group.entries + 1] = sourceEntryKey
                NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
            else
                -- 鎷栧埌鍚堥泦鏍囬涓?涓嬭竟缂樻椂锛屼笉鏄斁鍏ヨ鍚堥泦锛岃€屾槸鎷栧埌鍚堥泦澶栧眰銆?                -- 濡傛灉鐩爣鍚堥泦浣嶄簬鏍瑰垪琛紝鍒欐妸璇煶鎻掑埌鏍瑰垪琛ㄨ鍚堥泦鍓?鍚庯紱
                -- 濡傛灉鐩爣鍚堥泦鏈韩鍦ㄧ埗鍚堥泦閲岋紝鍒欐彃鍒扮埗鍚堥泦鍐呴儴璇ュ瓙鍚堥泦鍓?鍚庛€?
                local targetGroupKey = BuildGroupKey(targetClassID, targetSpecID, targetGroupID)
                local targetLoc = FindGroupKeyLocation(targetScope, targetGroupKey, targetClassID, targetSpecID)
                if not targetLoc then
                    return false
                end

                if sameScope then
                    while RemoveEntryKeyFromCollectionScope(targetScope, sourceEntryKey, targetClassID, targetSpecID) do end
                    if not InsertEntryKeyAtCollectionLocation(targetScope, sourceEntryKey, sourceIndex, targetLoc, insertAfter, true) then
                        -- 鎻掑叆澶辫触鏃舵妸鏉＄洰鏀惧洖鏍瑰垪琛ㄦ湯灏撅紝閬垮厤寮曠敤涓㈠け銆?
                        if type(targetScope.root) ~= "table" then
                            targetScope.root = {}
                        end
                        targetScope.root[#targetScope.root + 1] = { type = "entry", index = sourceIndex }
                    end
                    NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
                else
                    if targetLoc.container == "group" then
                        RemoveEntryKeyFromAllCollectionScopes(sourceEntryKey)
                        InsertEntryKeyAtCollectionLocation(targetScope, sourceEntryKey, sourceIndex, targetLoc, insertAfter, false)
                        NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
                    else
                        RecordSavedListDisplayMove(sourceEntryKey, targetGroupKey, displayTargetSection, insertAfter)
                    end
                end
            end
        else
            local targetClassID, targetSpecID, targetIndex = ParseEntryKey(targetKey)
            if targetClassID < 0 or targetSpecID < 0 or targetIndex <= 0 then
                return false
            end

            local targetScope = EnsureCollectionScope(targetClassID, targetSpecID)
            if not targetScope then
                return false
            end
            NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)

            local targetEntryKey = BuildEntryKey(targetClassID, targetSpecID, targetIndex)
            local loc = FindEntryKeyLocation(targetScope, targetEntryKey, targetClassID, targetSpecID)
            local sameScope = sourceClassID == targetClassID and sourceSpecID == targetSpecID

            if loc and loc.container == "group" then
                local group = targetScope.groups[loc.groupID]
                if type(group) ~= "table" then
                    return false
                end
                -- Same-scope moves only need local cleanup. Cross-scope drops still
                -- use the global cleanup to avoid duplicate references elsewhere.
                if sameScope then
                    while RemoveEntryKeyFromCollectionScope(targetScope, sourceEntryKey, targetClassID, targetSpecID) do end
                else
                    RemoveEntryKeyFromAllCollectionScopes(sourceEntryKey)
                end
                if type(group.entries) ~= "table" then
                    group.entries = {}
                end
                local insertPos = math.max(1, loc.position + (insertAfter and 1 or 0))
                table.insert(group.entries, math.min(insertPos, #group.entries + 1), sourceEntryKey)
                NormalizeCollectionScope(targetScope, api.GetStoredEntryMap(targetClassID, targetSpecID), targetClassID, targetSpecID)
            elseif loc and loc.container == "root" then
                if not sameScope then
                    RecordSavedListDisplayMove(sourceEntryKey, targetEntryKey, displayTargetSection, insertAfter)
                else
                    while RemoveEntryKeyFromCollectionScope(targetScope, sourceEntryKey, targetClassID, targetSpecID) do end
                    local insertPos = math.max(1, loc.position + (insertAfter and 1 or 0))
                    table.insert(targetScope.root, math.min(insertPos, #targetScope.root + 1), { type = "entry", index = sourceIndex })
                end
            else
                if not sameScope then
                    RecordSavedListDisplayMove(sourceEntryKey, targetEntryKey, displayTargetSection, insertAfter)
                else
                    while RemoveEntryKeyFromCollectionScope(targetScope, sourceEntryKey, targetClassID, targetSpecID) do end
                    targetScope.root[#targetScope.root + 1] = { type = "entry", index = sourceIndex }
                end
            end
        end

        if not sourceIsLoaded and not sourceWasInCurrentScope and targetIsGroup then
            print("[EUIVE] " .. L("MSG_DRAG_UNLOADED_TO_GROUP"))
        end
    end

    NormalizeCollectionScope(currentScope, api.GetStoredEntryMap(currentClassID, currentSpecID), currentClassID, currentSpecID)
    if not insertInside and not targetIsRoot then
        RecordSavedListDisplayMove(sourceKey, targetKey, displayTargetSection, insertAfter)
    end
    if not suppressRefresh then
        if not RequestNativeUIRefresh("list") and type(api.RefreshPanel) == "function" then
            api.RefreshPanel()
        end
    end
    return true
end
