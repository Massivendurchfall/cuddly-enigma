-- BananaEats Loader — redeem-first, uses syn.request/http_request/request (no direct HttpService)
-- GUI: English-only + explicit instructions how to get the key

-- === CONFIG ===
local API_BASE        = "https://odd-frog-e89b.dosrobert69.workers.dev/api"
local WORKINK_LINK    = "https://workink.net/22K7/7kr50x5g"
local MAIN_SCRIPT_URL = "https://raw.githubusercontent.com/Massivendurchfall/cuddly-enigma/refs/heads/main/x"
local LICENSE_DAYS    = 1
local SAVE_FILENAME   = "banana_key.txt"
-- === END CONFIG ===

local Players = game:GetService("Players")
local USER_ID = Players.LocalPlayer and Players.LocalPlayer.UserId or 0
local CAN_FS  = (typeof(isfile)=="function" and typeof(writefile)=="function" and typeof(readfile)=="function")

getgenv().BANANA_EATS = getgenv().BANANA_EATS or {}
local G = getgenv().BANANA_EATS

-- ---------- Tiny JSON helpers (no HttpService) ----------
local function esc(s) s=tostring(s or "") s=s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t'); return '"'..s..'"' end
local function json_encode(t)
    local p = {}
    for k,v in pairs(t or {}) do
        local tv = typeof(v)
        local val = (tv=="string" and esc(v)) or (tv=="number" and tostring(v)) or (tv=="boolean" and (v and "true" or "false")) or "null"
        p[#p+1] = esc(k)..":"..val
    end
    return "{"..table.concat(p,",").."}"
end
local function soft_parse(body)
    local o = {}
    if type(body)~="string" then return o end
    o.ok          = body:find('\"ok\"%s*:%s*true') ~= nil
    o.error       = body:match('\"error\"%s*:%s*\"([^\"]+)\"')
    o.license_key = body:match('\"license_key\"%s*:%s*\"([0-9a-fA-F%-]+)\"')
    return o
end

-- ---------- HTTP requester pick ----------
local function pickRequester()
    if syn and typeof(syn.request)=="function" then return syn.request end
    if http and typeof(http.request)=="function" then return http.request end
    if typeof(http_request)=="function" then return http_request end
    if typeof(request)=="function" then return request end
    return nil
end
local REQ = pickRequester()

local COMMON_HEADERS = {
    ["Content-Type"] = "application/json",
    ["User-Agent"]   = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
}

local function httpReqJson(url, method, bodyTbl)
    if not REQ then return nil, "no_http_available" end
    local bodyStr = bodyTbl and json_encode(bodyTbl) or nil
    local ok, r = pcall(REQ, { Url=url, Method=method, Headers=COMMON_HEADERS, Body=bodyStr })
    if not ok or not r then return nil, "request_failed" end
    local status = r.StatusCode or r.Status or 0
    local body   = r.Body or ""
    local parsed = soft_parse(body)
    return { status=status, body=body, json=parsed }
end

local function urlEncode(s) s=tostring(s or "") return (s:gsub("([^%w%-_%.~])", function(c) return string.format("%%%02X", string.byte(c)) end)) end

-- ---------- API wrappers (redeem first) ----------
local function redeemToken(tok)
    -- POST
    local r = httpReqJson(API_BASE.."/redeem_workink.php","POST",{workink_token=tok,roblox_user_id=USER_ID,license_days=LICENSE_DAYS})
    if r and r.status>=200 and r.json and r.json.ok and r.json.license_key then return r.json.license_key,nil end
    -- GET fallback
    local url = ("%s/redeem_workink.php?workink_token=%s&roblox_user_id=%d&license_days=%d"):format(API_BASE, urlEncode(tok), USER_ID, LICENSE_DAYS)
    r = httpReqJson(url,"GET")
    if r and r.status>=200 and r.json and r.json.ok and r.json.license_key then return r.json.license_key,nil end
    local err = (r and r.json and r.json.error) or (r and ("http_"..r.status)) or "network_error"
    if r and r.status==200 and (not r.json or (not r.json.ok and not r.json.error)) then
        err = "http_200 body_snip="..string.sub(r.body or "",1,120)
    end
    return nil, err
end

local function validateLicense(key)
    -- POST
    local r = httpReqJson(API_BASE.."/validate.php","POST",{license_key=key,roblox_user_id=USER_ID})
    if r and r.status>=200 and r.json and r.json.ok then return true,"valid" end
    -- GET fallback
    local url = ("%s/validate.php?license_key=%s&roblox_user_id=%d"):format(API_BASE, urlEncode(key), USER_ID)
    r = httpReqJson(url,"GET")
    if r and r.status>=200 and r.json and r.json.ok then return true,"valid" end
    local err = (r and r.json and r.json.error) or (r and ("http_"..r.status)) or "network_error"
    if r and r.status==200 and (not r.json or (not r.json.ok and not r.json.error)) then
        err = "http_200 body_snip="..string.sub(r.body or "",1,120)
    end
    return false, err
end

-- ---------- Key cache ----------
local function loadCachedKey()
    if type(G.LICENSE_KEY)=="string" and #G.LICENSE_KEY>0 then return G.LICENSE_KEY end
    if CAN_FS and isfile(SAVE_FILENAME) then
        local ok, content = pcall(readfile, SAVE_FILENAME)
        if ok and type(content)=="string" and #content>0 then return (content:gsub("%s+$","")) end
    end
    return nil
end
local function saveCachedKey(k) G.LICENSE_KEY=k; if CAN_FS then pcall(writefile, SAVE_FILENAME, k) end end

-- ---------- UI ----------
local function createUI()
    local g=Instance.new("ScreenGui"); g.Name="BananaKeyGate"; g.ResetOnSpawn=false; if syn and syn.protect_gui then pcall(syn.protect_gui,g) end; g.Parent=game.CoreGui

    local f=Instance.new("Frame"); f.Size=UDim2.new(0,560,0,260); f.Position=UDim2.new(0.5,-280,0.5,-130)
    f.BackgroundColor3=Color3.fromRGB(20,20,20); f.Active=true; f.Draggable=true; f.Parent=g; Instance.new("UICorner",f).CornerRadius=UDim.new(0,12)

    local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-20,0,36); title.Position=UDim2.new(0,10,0,10)
    title.Text="Banana Eats — License Check"; title.TextColor3=Color3.new(1,1,1); title.BackgroundTransparency=1
    title.TextXAlignment=Enum.TextXAlignment.Left; title.Font=Enum.Font.GothamBold; title.TextSize=18; title.Parent=f

    local status=Instance.new("TextLabel"); status.Size=UDim2.new(1,-20,0,22); status.Position=UDim2.new(0,10,0,46)
    status.Text=(REQ and "Paste your license key OR your Work.ink token below.") or "Your executor blocks HTTP (syn.request/http_request missing)."
    status.TextColor3=Color3.fromRGB(200,200,200); status.BackgroundTransparency=1; status.TextXAlignment=Enum.TextXAlignment.Left
    status.Font=Enum.Font.Gotham; status.TextSize=14; status.Name="Status"; status.Parent=f

    -- Instructions box (English-only, explicit steps)
    local help=Instance.new("TextLabel"); help.Size=UDim2.new(1,-20,0,80); help.Position=UDim2.new(0,10,0,70)
    help.BackgroundColor3=Color3.fromRGB(28,28,28); help.TextXAlignment=Enum.TextXAlignment.Left; help.TextYAlignment=Enum.TextYAlignment.Top
    help.TextColor3=Color3.fromRGB(220,220,220); help.Font=Enum.Font.Gotham; help.TextSize=12; help.RichText=true
    help.Text = table.concat({
        "How to get the key:",
        "\n1) Click <b>Copy Work.ink Link</b>.",
        "\n2) Press <b>Ctrl+V</b> (or long-press → Paste) in your web browser’s address bar.",
        "\n3) Complete the steps on Work.ink until you see a <b>token</b> or key.",
        "\n4) Copy that <b>token/key</b> and paste it here.",
        "\n5) Press <b>Continue</b>. The loader will redeem/validate automatically."
    },""); help.Parent=f; Instance.new("UICorner",help).CornerRadius=UDim.new(0,8)

    local box=Instance.new("TextBox"); box.Size=UDim2.new(1,-20,0,34); box.Position=UDim2.new(0,10,0,156)
    box.PlaceholderText="Paste license key OR Work.ink token here"; box.Text=""
    box.TextColor3=Color3.new(1,1,1); box.BackgroundColor3=Color3.fromRGB(35,35,35); box.ClearTextOnFocus=false
    box.Font=Enum.Font.Gotham; box.TextSize=14; Instance.new("UICorner",box).CornerRadius=UDim.new(0,8); box.Parent=f

    local go=Instance.new("TextButton"); go.Size=UDim2.new(0,180,0,34); go.Position=UDim2.new(0,10,0,200)
    go.Text="Continue"; go.TextColor3=Color3.new(1,1,1); go.BackgroundColor3=Color3.fromRGB(40,100,220)
    go.Font=Enum.Font.GothamBold; go.TextSize=14; Instance.new("UICorner",go).CornerRadius=UDim.new(0,8); go.Parent=f

    local clip=Instance.new("TextButton"); clip.Size=UDim2.new(0,160,0,34); clip.Position=UDim2.new(0,200,0,200)
    clip.Text="Paste from Clipboard"; clip.TextColor3=Color3.new(1,1,1); clip.BackgroundColor3=Color3.fromRGB(60,60,60)
    clip.Font=Enum.Font.Gotham; clip.TextSize=14; Instance.new("UICorner",clip).CornerRadius=UDim.new(0,8); clip.Parent=f

    local copyLink=Instance.new("TextButton"); copyLink.Size=UDim2.new(1,-20,0,26); copyLink.Position=UDim2.new(0,10,1,-34)
    copyLink.Text="➡ Copy Work.ink link (paste it into your browser):  "..WORKINK_LINK
    copyLink.TextColor3=Color3.fromRGB(220,220,220); copyLink.BackgroundColor3=Color3.fromRGB(45,45,45)
    copyLink.TextXAlignment=Enum.TextXAlignment.Left; copyLink.Font=Enum.Font.Gotham; copyLink.TextSize=12
    Instance.new("UICorner",copyLink).CornerRadius=UDim.new(0,6); copyLink.Parent=f

    copyLink.MouseButton1Click:Connect(function()
        if typeof(setclipboard)=="function" then
            pcall(setclipboard, WORKINK_LINK)
            status.Text="Work.ink link copied. Open your browser, paste (Ctrl+V), finish steps, then copy the token."
        else
            status.Text="Cannot copy automatically. Manually copy this link: "..WORKINK_LINK
        end
    end)

    clip.MouseButton1Click:Connect(function()
        if typeof(getclipboard)=="function" then
            local ok,v=pcall(getclipboard)
            if ok and type(v)=="string" and #v>0 then
                box.Text=v; status.Text="Pasted from clipboard."
            else
                status.Text="Clipboard is empty."
            end
        else
            status.Text="Your executor does not support getclipboard(). Paste manually."
        end
    end)

    return g,status,box,go
end

local Gui, Status, InputBox, ContinueBtn = createUI()
if not REQ then
    -- Still allow manual key entry if executor suddenly exposes request later; otherwise we stop here.
    warn("[BananaEats] No HTTP function available (syn.request/http_request/request).")
end

-- Auto-validate cached key
task.spawn(function()
    local ex = loadCachedKey()
    if ex then
        Status.Text="Checking saved license key..."
        local ok, reason = validateLicense(ex)
        if ok then
            Status.Text="License valid. Loading main script..."
            saveCachedKey(ex); task.wait(0.3); if Gui then Gui:Destroy() end
            local ok2,err2=pcall(function() loadstring(game:HttpGet(MAIN_SCRIPT_URL,true))() end)
            if not ok2 then warn("Main script error: ",err2) end
        else
            Status.Text="Saved key invalid: "..tostring(reason)
        end
    end
end)

ContinueBtn.MouseButton1Click:Connect(function()
    local text = (InputBox.Text or ""):gsub("^%s+",""):gsub("%s+$","")
    if text=="" then Status.Text="Input is empty. Paste your key or token first."; return end

    if not REQ then
        Status.Text="Cannot contact server (no HTTP). Try a different executor."
        return
    end

    -- 1) ALWAYS try redeem first (token case)
    Status.Text = "Redeeming your token on the server..."
    local lic, err = redeemToken(text)
    if lic then
        InputBox.Text = lic
        Status.Text = "Your license key: "..lic
        if typeof(setclipboard)=="function" then pcall(setclipboard, lic); Status.Text="Your license key: "..lic.." (copied)" end
        saveCachedKey(lic); task.wait(0.6)
        Status.Text="Validating license..."
        local ok, reason = validateLicense(lic)
        if ok then
            Status.Text="License valid. Loading main script..."
            task.wait(0.3); if Gui then Gui:Destroy() end
            local ok2,err2=pcall(function() loadstring(game:HttpGet(MAIN_SCRIPT_URL,true))() end)
            if not ok2 then warn("Main script error: ",err2) end
        else
            Status.Text="Validation failed after redeem: "..tostring(reason)
        end
        return
    end

    -- 2) If redeem says token problem -> treat as KEY validate
    if tostring(err):find("token_invalid") or tostring(err):find("bad_request_no_token") then
        Status.Text = "Redeem says '"..tostring(err).."'. Trying as license key..."
        local ok, reason = validateLicense(text)
        if ok then
            saveCachedKey(text)
            Status.Text="License valid. Loading main script..."
            task.wait(0.3); if Gui then Gui:Destroy() end
            local ok2,err2=pcall(function() loadstring(game:HttpGet(MAIN_SCRIPT_URL,true))() end)
            if not ok2 then warn("Main script error: ",err2) end
        else
            Status.Text="License invalid: "..tostring(reason)
        end
    else
        -- other errors (e.g. HTML body) -> show raw hint
        Status.Text = "Redeem failed: "..tostring(err)..". If you used a token, re-check the browser steps."
        warn("[BananaEats] Redeem error: "..tostring(err))
    end
end)
