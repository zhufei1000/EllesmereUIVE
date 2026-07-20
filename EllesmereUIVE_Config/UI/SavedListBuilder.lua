local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListBuilder = NS.UI.SavedListBuilder or {}

local Builder = NS.UI.SavedListBuilder
local Utils = NS.Utils or {}

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

function Builder.ParseGroupKey(key)
    local classID, specID, groupID = tostring(key or ""):match("^group:(%-?%d+):(%-?%d+):(.+)$")
    return tonumber(classID) or 0, tonumber(specID) or 0, tostring(groupID or "")
end

function Builder.GetGroupDataByKey(groupKey)
    local classID, specID, groupID = Builder.ParseGroupKey(groupKey)
    local db = type(EllesmereUIVEDB) == "table" and EllesmereUIVEDB or nil
    local classMap = db and type(db.collectionData) == "table" and db.collectionData[classID] or nil
    local scope = type(classMap) == "table" and classMap[specID] or nil
    local group = type(scope) == "table" and type(scope.groups) == "table" and scope.groups[groupID] or nil
    if type(group) ~= "table" then
        return nil
    end
    return group, scope, classID, specID, groupID
end

function Builder.IsGroupCollapsed(groupKey)
    local group = Builder.GetGroupDataByKey(groupKey)
    return type(group) == "table" and group.collapsed == true
end

function Builder.ToggleGroupCollapsed(groupKey)
    local group = Builder.GetGroupDataByKey(groupKey)
    if type(group) == "table" then
        group.collapsed = not (group.collapsed == true)
        return true
    end
    if NS.AceOptions and type(NS.AceOptions.ToggleCollectionCollapsed) == "function" then
        return NS.AceOptions:ToggleCollectionCollapsed(groupKey)
    end
    return false
end

function Builder.CountVisibleHeaderItems(rows)
    local count = 0
    for _, entry in ipairs(rows or {}) do
        if tostring(entry and entry.itemType or "entry") ~= "group-empty" then
            count = count + 1
        end
    end
    return count
end

function Builder.CollapseCachedGroupRows(rows, groupKey)
    groupKey = TrimText(groupKey)
    if groupKey == "" or type(rows) ~= "table" then
        return false, rows
    end

    local result = {}
    local found = false
    local skipDepth = nil

    for _, entry in ipairs(rows) do
        local depth = tonumber(entry and entry.depth) or 0
        if skipDepth and depth > skipDepth then
            -- Drop visible descendants from the current cached layout. This makes
            -- collapsing instant and avoids rebuilding all saved scopes.
        else
            skipDepth = nil
            if TrimText(entry and entry.key) == groupKey and tostring(entry and entry.itemType or "") == "group" then
                entry.collapsed = true
                found = true
                skipDepth = depth
            end
            result[#result + 1] = entry
        end
    end

    return found, result
end



function Builder.ExpandCachedGroupRows(rows, groupKey)
    groupKey = TrimText(groupKey)
    if groupKey == "" or type(rows) ~= "table" then
        return false, rows
    end

    local classID, specID = Builder.ParseGroupKey(groupKey)
    local sectionKey = nil
    local insertIndex = nil
    local groupDepth = 0

    for index, entry in ipairs(rows) do
        if TrimText(entry and entry.key) == groupKey and tostring(entry and entry.itemType or "") == "group" then
            sectionKey = tostring(entry.displaySection or "")
            insertIndex = index
            groupDepth = tonumber(entry.depth) or 0
            entry.collapsed = false
            break
        end
    end

    if not insertIndex then
        return false, rows
    end

    -- Rebuild only the affected collection scope instead of the whole saved list.
    local scopeRows = NS.AceOptions:GetSavedListLayoutForScope(classID, specID, true)
    if type(scopeRows) ~= "table" then
        return false, rows
    end

    local descendants = {}
    local found = false
    local scopeGroupDepth = 0
    for _, entry in ipairs(scopeRows) do
        local key = TrimText(entry and entry.key)
        local depth = tonumber(entry and entry.depth) or 0
        if not found then
            if key == groupKey and tostring(entry and entry.itemType or "") == "group" then
                found = true
                scopeGroupDepth = depth
                local cachedGroup = rows[insertIndex]
                if type(cachedGroup) == "table" then
                    cachedGroup.count = entry.count
                    cachedGroup.loadedCount = entry.loadedCount
                    cachedGroup.unloadedCount = entry.unloadedCount
                    cachedGroup.loadState = entry.loadState
                    cachedGroup.isLoaded = entry.isLoaded
                    cachedGroup.isEmptyCollection = entry.isEmptyCollection
                    cachedGroup.collapsed = false
                end
            end
        else
            if depth <= scopeGroupDepth then
                break
            end
            -- Keep the parent section for visible child rows so an unloaded child
            -- inside a loaded collection does not jump to the global unloaded block.
            entry.displaySection = sectionKey
            descendants[#descendants + 1] = entry
        end
    end

    if not found then
        return false, rows
    end

    -- Remove any stale descendants already present after this group, then splice
    -- the freshly built descendants in. This makes expand/collapse local.
    local result = {}
    local i = 1
    while i <= #rows do
        local entry = rows[i]
        result[#result + 1] = entry
        if i == insertIndex then
            i = i + 1
            while i <= #rows do
                local child = rows[i]
                local childDepth = tonumber(child and child.depth) or 0
                if childDepth <= groupDepth then
                    break
                end
                i = i + 1
            end
            for _, child in ipairs(descendants) do
                result[#result + 1] = child
            end
        else
            i = i + 1
        end
    end

    return true, result
end

function Builder.BuildLayout(list, state)
    local entries = NS.AceOptions:GetAllSavedEntryList()
    local api = NS.API
    local currentClassID, currentSpecID = api.GetCurrentClassSpec()
    local scopeLayoutCache = {}

    local function getScopeLayout(scopeClassID, scopeSpecID, includeScopeText)
        scopeClassID = tonumber(scopeClassID) or 0
        scopeSpecID = tonumber(scopeSpecID) or 0
        local cacheKey = table.concat({ scopeClassID, scopeSpecID, includeScopeText == true and "1" or "0" }, ":")
        if scopeLayoutCache[cacheKey] then
            return scopeLayoutCache[cacheKey]
        end
        local rows = NS.AceOptions:GetSavedListLayoutForScope(scopeClassID, scopeSpecID, includeScopeText)
        if type(rows) ~= "table" then
            rows = {}
        end
        scopeLayoutCache[cacheKey] = rows
        return rows
    end

    local loadedEntries = {}
    local unloadedEntries = {}
    local entriesAlreadyShownWithLoaded = {}

    local function markEntryKeyShown(key)
        key = TrimText(key)
        if key ~= "" then
            entriesAlreadyShownWithLoaded[key] = true
        end
    end

    local function markShown(entry)
        markEntryKeyShown(entry and entry.key)
    end

    local function markGroupContainedEntries(groupKey, seenGroups)
        groupKey = TrimText(groupKey)
        if groupKey == "" then
            return
        end
        seenGroups = seenGroups or {}
        if seenGroups[groupKey] then
            return
        end
        seenGroups[groupKey] = true

        local group = Builder.GetGroupDataByKey(groupKey)
        if type(group) ~= "table" then
            return
        end
        for _, ref in ipairs(group.entries or {}) do
            local refText = TrimText(ref)
            if refText:match("^group:") then
                markGroupContainedEntries(refText, seenGroups)
            elseif refText:match("^%-?%d+:%-?%d+:%-?%d+$") then
                markEntryKeyShown(refText)
            end
        end
    end

    local function appendGroup(sectionRows, groupRow, childRows)
        if type(groupRow) ~= "table" then
            return
        end

        local count = tonumber(groupRow.count) or 0
        for _, child in ipairs(childRows or {}) do
            if tostring(child.itemType or "entry") == "entry" then
                markShown(child)
            end
        end
        markGroupContainedEntries(groupRow.key)

        groupRow.isEmptyCollection = count <= 0
        groupRow.collapsed = (count <= 0) or Builder.IsGroupCollapsed(groupRow.key) or groupRow.collapsed == true
        sectionRows[#sectionRows + 1] = groupRow

        if count > 0 and not groupRow.collapsed then
            for _, child in ipairs(childRows or {}) do
                sectionRows[#sectionRows + 1] = child
            end
        end
    end

    local function flushCollectedGroup(groupRow, childRows)
        if type(groupRow) ~= "table" then
            return
        end

        local childCount = tonumber(groupRow.count) or 0
        local loadState = tostring(groupRow.loadState or "")
        local hasLoadedChild = loadState == "green" or loadState == "yellow"

        -- 合集显示规则：
        -- 1. 空合集固定显示在“已载入”；
        -- 2. 合集内只要有一个已载入条目，整个合集显示在“已载入”，未载入子项保留红点；
        -- 3. 只有合集内全部子项都是未载入时，合集才显示到“未载入”。
        if childCount <= 0 or hasLoadedChild then
            groupRow.isLoaded = true
            appendGroup(loadedEntries, groupRow, childRows)
        else
            groupRow.isLoaded = false
            appendGroup(unloadedEntries, groupRow, childRows)
        end
    end

    local function appendGroupsFromScope(scopeClassID, scopeSpecID)
        local scopeEntries = getScopeLayout(scopeClassID, scopeSpecID, true)
        local currentGroup = nil
        local currentChildren = nil

        for _, entry in ipairs(scopeEntries) do
            local itemType = tostring(entry.itemType or "entry")
            local depth = tonumber(entry.depth) or 0
            if itemType == "group" and depth == 0 then
                flushCollectedGroup(currentGroup, currentChildren)
                currentGroup = entry
                currentChildren = {}
            elseif currentGroup and depth > 0 then
                -- 子合集和子条目都跟随顶层合集显示，避免未载入子项跑到外面的未载入区。
                currentChildren[#currentChildren + 1] = entry
            else
                flushCollectedGroup(currentGroup, currentChildren)
                currentGroup = nil
                currentChildren = nil
            end
        end

        flushCollectedGroup(currentGroup, currentChildren)
    end

    local function appendRootEntriesForScope(scopeClassID, scopeSpecID, includeScopeText)
        local scopeEntries = getScopeLayout(scopeClassID, scopeSpecID, includeScopeText)
        for _, entry in ipairs(scopeEntries) do
            if tostring(entry.itemType or "entry") == "entry" and not entry.groupID then
                local key = TrimText(entry.key)
                if key ~= "" and not entriesAlreadyShownWithLoaded[key] then
                    if entry.isLoaded == false then
                        unloadedEntries[#unloadedEntries + 1] = entry
                    else
                        loadedEntries[#loadedEntries + 1] = entry
                    end
                    markShown(entry)
                end
            end
        end
    end

    local function iterSortedNumberKeys(map, callback)
        local keys = {}
        for key, value in pairs(map or {}) do
            local num = tonumber(key)
            if num and type(value) == "table" then
                keys[#keys + 1] = { num = num, value = value }
            end
        end
        table.sort(keys, function(a, b) return a.num < b.num end)
        for _, item in ipairs(keys) do
            callback(item.num, item.value)
        end
    end

    local db = type(EllesmereUIVEDB) == "table" and EllesmereUIVEDB or nil
    if db and type(db.collectionData) == "table" then
        iterSortedNumberKeys(db.collectionData, function(scopeClassID, classMap)
            iterSortedNumberKeys(classMap, function(scopeSpecID)
                appendGroupsFromScope(scopeClassID, scopeSpecID)
            end)
        end)
    end

    -- 已载入的根条目 = 全职业 + 当前职业“全专精” + 当前实际专精。合集已在上面按规则单独归类。
    appendRootEntriesForScope(0, 0, true)
    appendRootEntriesForScope(currentClassID, 0, currentSpecID ~= 0)
    if currentSpecID ~= 0 then
        appendRootEntriesForScope(currentClassID, currentSpecID, false)
    end

    for _, entry in ipairs(entries) do
        local key = TrimText(entry.key)
        if key ~= "" and not entriesAlreadyShownWithLoaded[key] then
            local isLoadedScope = entry.isLoaded == true
            entry.itemType = "entry"
            if isLoadedScope then
                loadedEntries[#loadedEntries + 1] = entry
            else
                unloadedEntries[#unloadedEntries + 1] = entry
            end
            entriesAlreadyShownWithLoaded[key] = true
        end
    end

    local function applyDisplayOrder(sectionKey, rows)
        local db = type(EllesmereUIVEDB) == "table" and EllesmereUIVEDB or nil
        if not db then
            return rows
        end
        if type(db.savedListOrder) ~= "table" then
            db.savedListOrder = {}
        end
        if type(db.savedListOrder[sectionKey]) ~= "table" then
            db.savedListOrder[sectionKey] = {}
        end

        local order = db.savedListOrder[sectionKey]
        local blocks = {}
        local byKey = {}
        local i = 1
        while i <= #(rows or {}) do
            local row = rows[i]
            local block = { rows = { row }, key = TrimText(row and row.key) }
            local depth = tonumber(row and row.depth) or 0
            i = i + 1
            if tostring(row and row.itemType or "") == "group" then
                while i <= #rows do
                    local child = rows[i]
                    local childDepth = tonumber(child and child.depth) or 0
                    if childDepth <= depth then
                        break
                    end
                    block.rows[#block.rows + 1] = child
                    i = i + 1
                end
            end
            blocks[#blocks + 1] = block
            if block.key ~= "" and not byKey[block.key] then
                byKey[block.key] = block
            end
        end

        local used = {}
        local sorted = {}
        local cleanedOrder = {}
        for _, key in ipairs(order) do
            key = TrimText(key)
            local block = byKey[key]
            if block and not used[key] then
                sorted[#sorted + 1] = block
                used[key] = true
                cleanedOrder[#cleanedOrder + 1] = key
            end
        end
        for _, block in ipairs(blocks) do
            local key = block.key
            if key == "" or not used[key] then
                sorted[#sorted + 1] = block
                if key ~= "" then
                    cleanedOrder[#cleanedOrder + 1] = key
                    used[key] = true
                end
            end
        end

        local result = {}
        for _, block in ipairs(sorted) do
            for _, row in ipairs(block.rows or {}) do
                row.displaySection = sectionKey
                result[#result + 1] = row
            end
        end
        db.savedListOrder[sectionKey] = cleanedOrder
        return result
    end

    loadedEntries = applyDisplayOrder("loaded", loadedEntries)
    unloadedEntries = applyDisplayOrder("unloaded", unloadedEntries)

    return loadedEntries, unloadedEntries, Builder.CountVisibleHeaderItems(loadedEntries), Builder.CountVisibleHeaderItems(unloadedEntries)
end
