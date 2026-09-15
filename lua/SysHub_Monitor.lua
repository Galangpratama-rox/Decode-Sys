--[[
================================================================================
  SYSHUB MONITOR  v1.0
  Berdasarkan SagaHub_Monitor.lua v2.3
  Game  : Steal An Egg (GameId: 10563114921)
  Endpoint: sama dengan SagaHub Monitor backend
  DATA YANG DIKIRIM:
    - Basic: username, userId, placeId, ping, position, leaderstats
    - Plot snapshot: income, speed, plotLevel, plotEggCount, petCount
    - placedEggs: array egg yang ditanam (name, rarity, ratePerSecond, weightKg, mutations)
    - pets: pet aktif (name, ratePerSecond, mutations)
    - backpackEggCount, backpackPetCount
================================================================================
--]]

-- ============================================================
-- CONFIG
-- ============================================================
local MONITOR_ENDPOINT = "https://backend-monitoring-sae-production-a7b9.up.railway.app/api/monitor"
local MONITOR_INTERVAL = 45
local MONITOR_KEY      = "sagahub-secret-key"

-- ============================================================
-- SETUP
-- ============================================================
local ge      = (getgenv and getgenv()) or _G
local Players = game:GetService("Players")
local lp      = Players.LocalPlayer
local hs      = game:GetService("HttpService")

if not lp then
    warn("[SysHubMonitor] LocalPlayer tidak ada, abort")
    return
end

-- ============================================================
-- REQUEST HELPER
-- coba semua method executor: http_request, request, syn.request
-- fallback ke HttpService:RequestAsync
-- ============================================================
local function doRequest(url, method, headers, body)
    local opts = {
        Url     = url,
        Method  = method or "POST",
        Headers = headers or {},
        Body    = body or "",
    }

    -- http_request (Real, Fluxus, KRNL, dll)
    if http_request then
        local ok, res = pcall(http_request, opts)
        if ok and res and (res.StatusCode or 0) > 0 then return res end
    end

    -- request (Delta, Wave, dll)
    if request then
        local ok, res = pcall(request, opts)
        if ok and res and (res.StatusCode or 0) > 0 then return res end
    end

    -- syn.request (Synapse)
    if syn and syn.request then
        local ok, res = pcall(syn.request, opts)
        if ok and res and (res.StatusCode or 0) > 0 then return res end
    end

    -- http.request
    if http and http.request then
        local ok, res = pcall(http.request, opts)
        if ok and res and (res.StatusCode or 0) > 0 then return res end
    end

    -- fallback HttpService:RequestAsync
    local hs2 = game:GetService("HttpService")
    local ok, res = pcall(function()
        return hs2:RequestAsync(opts)
    end)
    if ok and res and (res.StatusCode or 0) > 0 then return res end

    return nil
end

warn("[SysHubMonitor] Request helper siap")

-- ============================================================
-- HELPER
-- ============================================================
local function safeNum(v)
    return tonumber(v) or 0
end

-- ============================================================
-- MODULE CACHE — require sekali saat load
-- ============================================================
local _EggState    = nil
local _AssetRoster = nil
local _PlotState   = nil
local _Assets      = nil
local _Mutations   = nil
local _Dir         = nil

local _lastPetsData    = nil
local _petsSkipCounter = 0

local _mutCache = {}
local function getMutScalar(mutName)
    if not mutName or mutName == "" or mutName == "nil" then return 1.0 end
    if _mutCache[mutName] then return _mutCache[mutName] end
    if _Mutations and type(_Mutations.Get) == "function" then
        local ok, cfg = pcall(_Mutations.Get, mutName)
        local scalar = (ok and type(cfg) == "table") and (cfg.EarningsScalar or 1.0) or 1.0
        _mutCache[mutName] = scalar
        return scalar
    end
    return 1.0
end

-- __FyyCommunityStealAnEgg cache
local _saeCache = nil
local function getSAE()
    if _saeCache then return _saeCache end
    local ge2 = (getgenv and getgenv()) or _G
    local sae = rawget(ge2, "__FyyCommunityStealAnEgg")
    if type(sae) == "table" then _saeCache = sae end
    return sae
end

-- init modules
do
    local rs2 = game:GetService("ReplicatedStorage")
    local function tryRequire(path)
        local ok, m = pcall(require, path)
        return ok and m or nil
    end
    _EggState    = tryRequire(rs2.Client.EggState)
    _AssetRoster = tryRequire(rs2.Client.AssetRoster)
    _PlotState   = tryRequire(rs2.Client.PlotState)
    _Assets      = tryRequire(rs2.Data.Assets)
    _Mutations   = tryRequire(rs2.Shared.Modules.Mutations)
    if _Assets and type(_Assets.Directory) == "table" then
        _Dir = _Assets.Directory
    end
end

-- ============================================================
-- EGG & PLOT DATA COLLECTOR
-- ============================================================
local function getEggAndPlotData(stats)
    local ok1 = _EggState    ~= nil
    local ok2 = _AssetRoster ~= nil
    local ok3 = _PlotState   ~= nil

    -- ── Placed eggs via EggState ──────────────────────────────
    pcall(function()
        if not ok1 then return end
        local sae = getSAE()
        if type(sae) ~= "table" then return end
        local weightUtil = sae.eggRuntime and sae.eggRuntime.weightUtil
        if type(weightUtil) ~= "table" then return end

        local dir = _Dir
        local okR, owned = pcall(_EggState.ReadOwnedEggs)
        if not okR or type(owned) ~= "table" then return end

        local myEntry = nil
        for _, entry in ipairs(owned) do
            if type(entry) == "table"
                and type(entry.OwnerUserId) == "number"
                and entry.OwnerUserId == lp.UserId then
                myEntry = entry
                break
            end
        end
        if not myEntry or type(myEntry.Records) ~= "table" then return end

        local plotEggs = {}
        for uid in pairs(myEntry.Records) do
            local okF, rec = pcall(_EggState.FetchEggRecord, uid)
            if not okF or type(rec) ~= "table" then
                rec = sae.eggRuntime.records and sae.eggRuntime.records[uid]
            end
            if type(rec) == "table" then
                local category = tostring(rec.AssetCategory or "Unknown")
                if category ~= "Unknown" then
                    -- WeightKg aktual
                    local ok_w, weightKg = pcall(weightUtil.WeightKg, rec)
                    weightKg = (ok_w and type(weightKg) == "number" and weightKg > 0)
                        and weightKg or 0

                    -- SellPrice
                    local ok_s, sellPrice = pcall(weightUtil.SellPrice, rec)
                    sellPrice = (ok_s and type(sellPrice) == "number")
                        and sellPrice or 0

                    -- Fallback weight dari Directory
                    if weightKg <= 0 then
                        local dirE   = dir and dir[category]
                        local baseW  = dirE and dirE.Egg and safeNum(dirE.Egg.WeightKg or 0) or 0
                        local scale  = safeNum(rec.AssetScale or 1)
                        weightKg     = baseW * scale
                    end

                    local dirEntry   = dir and dir[category]
                    local eggData    = (dirEntry and type(dirEntry.Egg)    == "table") and dirEntry.Egg    or {}
                    local rarityData = (dirEntry and type(dirEntry.Rarity) == "table") and dirEntry.Rarity or {}

                    local displayName = tostring(eggData.DisplayName    or category .. " Egg")
                    local rarity      = tostring(rarityData._id          or rarityData.DisplayName or "Unknown")

                    local muts = {}
                    if type(rec.Mutations) == "table" then
                        for _, m in ipairs(rec.Mutations) do
                            table.insert(muts, tostring(m))
                        end
                    end

                    local baseMut       = tostring(rec.BaseMutation or "")
                    local earningsScalar = getMutScalar(baseMut)
                    for _, m in ipairs(muts) do
                        local s = getMutScalar(m)
                        if s > earningsScalar then earningsScalar = s end
                    end

                    local ratePerSec = math.floor(sellPrice * 3 / 200 / 1.2 * earningsScalar)

                    if weightKg > 0 then
                        table.insert(plotEggs, {
                            name          = displayName,
                            rarity        = rarity,
                            weightKg      = math.floor(weightKg * 100) / 100,
                            ratePerSecond = ratePerSec,
                            mutations     = muts,
                        })
                    end
                end
            end
        end

        table.sort(plotEggs, function(a, b)
            return a.ratePerSecond > b.ratePerSecond
        end)

        if #plotEggs > 0 then
            stats.plotEggs     = plotEggs
            stats.plotEggCount = #plotEggs
        end
    end)

    -- ── Pets dari AssetRoster ─────────────────────────────────
    pcall(function()
        if not ok2 then return end
        _petsSkipCounter = (_petsSkipCounter or 0) + 1
        if _petsSkipCounter < 3 then
            if _lastPetsData then
                stats.pets     = _lastPetsData
                stats.petCount = #_lastPetsData
            end
            return
        end
        _petsSkipCounter = 0

        local snap = _AssetRoster.ReadSnapshot()
        if type(snap) ~= "table" then return end

        local mySnap = nil
        for _, s in ipairs(snap) do
            if type(s) == "table"
                and type(s.OwnerUserId) == "number"
                and s.OwnerUserId == lp.UserId then
                mySnap = s
                break
            end
        end
        if not mySnap then return end

        local records = mySnap.Records
        if type(records) ~= "table" then return end

        local pets = {}
        for _, rec in pairs(records) do
            if type(rec) == "table" then
                if not (rec.OwnerUserId and rec.OwnerUserId ~= lp.UserId) then
                    local item    = rec.ItemData or {}
                    local muts    = {}
                    if type(item.Mutations) == "table" then
                        for _, m in ipairs(item.Mutations) do
                            table.insert(muts, tostring(m))
                        end
                    end
                    local petRate = safeNum(rec.MoneyPerSecond)
                    if petRate > 0 then
                        table.insert(pets, {
                            name          = tostring(item.Category or "Unknown"),
                            ratePerSecond = petRate,
                            mutations     = muts,
                        })
                    end
                end
            end
        end

        table.sort(pets, function(a, b) return a.ratePerSecond > b.ratePerSecond end)

        if #pets > 0 then
            stats.pets     = pets
            stats.petCount = #pets
            _lastPetsData  = pets
        end
    end)

    -- ── Plot snapshot dari PlotState ──────────────────────────
    pcall(function()
        if not ok3 then return end
        local slotNum = _PlotState.ResolveLocalSlot()
        if type(slotNum) ~= "number" then return end

        local folder    = _PlotState.ResolveFolder(slotNum)
        local plotLevel = 0
        if typeof(folder) == "Instance" then
            local plotModel = folder:FindFirstChild(tostring(slotNum))
            if plotModel then
                local lvl = plotModel:GetAttribute("BaseUpgradeLevel")
                if lvl then plotLevel = safeNum(lvl) end
            end
        end

        local income = 0
        if stats.leaderstats then
            income = safeNum(stats.leaderstats["Money/s"] or 0)
        end

        stats.plotSnapshot = {
            slotNumber   = slotNum,
            plotLevel    = plotLevel,
            plotEggCount = stats.plotEggCount or 0,
            petCount     = stats.petCount     or 0,
            income       = income,
        }
    end)
end

-- ============================================================
-- MAIN DATA COLLECTOR
-- ============================================================
local function getPlayerStats()
    local stats = {}

    pcall(function()
        -- Basic info
        stats.username    = lp.Name
        stats.displayName = lp.DisplayName
        stats.userId      = lp.UserId
        stats.placeId     = game.PlaceId
        stats.jobId       = game.JobId
        stats.serverTime  = os.time()
        stats.playerCount = #Players:GetPlayers()

        -- Ping
        pcall(function()
            stats.ping = math.floor(
                game:GetService("Stats").Network.ServerStatsItem["Data Ping"].Value
            )
        end)

        -- Leaderstats
        pcall(function()
            local ls = lp:FindFirstChild("leaderstats")
            if ls then
                stats.leaderstats = {}
                for _, v in ipairs(ls:GetChildren()) do
                    stats.leaderstats[v.Name] = tostring(v.Value)
                end
            end
        end)

        -- Position
        pcall(function()
            local char = lp.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    stats.position = {
                        x = math.floor(hrp.Position.X),
                        y = math.floor(hrp.Position.Y),
                        z = math.floor(hrp.Position.Z),
                    }
                end
            end
        end)
    end)

    -- Egg & Plot data
    getEggAndPlotData(stats)

    return stats
end

-- ============================================================
-- SEND
-- ============================================================
local function sendMonitorData()
    local data  = getPlayerStats()
    data._key   = MONITOR_KEY
    data._type  = "monitor"
    data._ts    = os.time()

    local ok, encoded = pcall(function()
        return hs:JSONEncode(data)
    end)
    if not ok or not encoded then
        warn("[SysHubMonitor] JSON encode gagal: " .. tostring(encoded))
        return false
    end

    local req_ok, resp = pcall(function()
        return doRequest(
            MONITOR_ENDPOINT, "POST",
            {
                ["Content-Type"]  = "application/json",
                ["X-Monitor-Key"] = MONITOR_KEY,
            },
            encoded
        )
    end)

    if req_ok and resp and type(resp) == "table" then
        local sc = resp.StatusCode or resp.Status or 0
        if sc >= 200 and sc < 300 then
            return true
        else
            warn("[SysHubMonitor] Server error: " .. tostring(sc))
            return false
        end
    else
        warn("[SysHubMonitor] Request gagal: " .. tostring(resp))
        return false
    end
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
task.spawn(function()
    task.wait(3)  -- tunggu SysHub fully loaded dulu
    local success = sendMonitorData()
    if success then
        warn("[SysHubMonitor] ✅ Data pertama terkirim ke " .. MONITOR_ENDPOINT)
    else
        warn("[SysHubMonitor] ❌ Gagal kirim data pertama")
    end

    while true do
        task.wait(MONITOR_INTERVAL)
        if not lp or not lp.Parent then
            warn("[SysHubMonitor] Player left, monitor stop")
            break
        end
        pcall(sendMonitorData)
    end
end)

warn("[SysHubMonitor] Monitor v1.0 aktif — interval: " .. MONITOR_INTERVAL .. "s")
warn("[SysHubMonitor] Endpoint: " .. MONITOR_ENDPOINT)
