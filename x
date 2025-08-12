local function autoCakeAll()
    local lp = Players.LocalPlayer
    local char = lp.Character or lp.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    -- Main plate (die große Zielplatte im Puzzles-Ordner)
    local mainPlate = getMainCakePlatePart()
    if not mainPlate then return end

    -- einmal zur Main Plate porten und dort bleiben
    local stayCF = mainPlate.CFrame + Vector3.new(0, 3, 0)
    local function touchMainPlate()
        -- kleiner Jiggle direkt über die Platte, um Touch/Interaction sicher auszulösen
        hrp.CFrame = mainPlate.CFrame + Vector3.new(0, 3, 0)
        task.wait(0.05)
        hrp.CFrame = mainPlate.CFrame + Vector3.new(0, 1.2, 0)
        task.wait(0.05)
        hrp.CFrame = stayCF
        task.wait(0.05)
    end

    local original = hrp.CFrame
    hrp.CFrame = stayCF
    task.wait(0.2)

    -- alle CakePlates durchgehen
    for _, plate in ipairs(listCakePlates()) do
        -- nur wenn dort noch ein Stück liegt
        local cakeMesh = findCakeMesh(plate)
        if cakeMesh and cakeMesh.Parent then
            local cd = findCakeClickDetector(plate)
            if cd then
                -- remote pickup (Reichweite auf unendlich)
                pcall(function() if cd.MaxActivationDistance then cd.MaxActivationDistance = math.huge end end)
                for i = 1, 8 do
                    pcall(function() fireclickdetector(cd) end)
                    task.wait(0.05)
                end
                -- jetzt ablegen: Main Plate touchen
                touchMainPlate()

                -- falls das Stück wider Erwarten noch liegt, einmal lokal näher ran gehen und erneut klicken
                if findCakeMesh(plate) and findCakeMesh(plate).Parent then
                    local tpPart = plateTeleportPart(plate)
                    if tpPart then
                        hrp.CFrame = tpPart.CFrame + Vector3.new(0, 3, 0)
                        task.wait(0.12)
                        for i = 1, 10 do
                            pcall(function() fireclickdetector(cd) end)
                            task.wait(0.05)
                        end
                    end
                    -- wieder zurück zur Main Plate und sicher ablegen
                    hrp.CFrame = stayCF
                    task.wait(0.12)
                    touchMainPlate()
                end
            end
        end
    end

    hrp.CFrame = original
end
