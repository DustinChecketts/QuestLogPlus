-- Declare addon name and namespace
local addOnName, ns = ...

-- Create the main frame for the addon
local QuestLogPlus = CreateFrame("FRAME")
QuestLogPlus:RegisterEvent("ADDON_LOADED")

-- Event handler for ADDON_LOADED event
function QuestLogPlus:ADDON_LOADED(loadedAddOnName)
    if loadedAddOnName == addOnName then
        -- Hook into the QuestLog_Update function to customize quest display
        hooksecurefunc("QuestLog_Update", function()
            QuestLogPlus:QuestLog_Update()
        end)
    end
end

-- Function to update the quest log display
function QuestLogPlus:QuestLog_Update()
    local numEntries = GetNumQuestLogEntries()
    local scrollOffset = HybridScrollFrame_GetOffset(QuestLogListScrollFrame)
    local buttons = QuestLogListScrollFrame.buttons

    for i = 1, #buttons do
        local questIndex = i + scrollOffset
        local questLogTitle = buttons[i]

        if questIndex <= numEntries then
            local _, level = GetQuestLogTitle(questIndex)
            local questText = questLogTitle:GetText()

            -- Check if the level is greater than 0 and if both level and quest text are available
            if level and level > 0 and questText then
                local questTextFormatted = format("[%d] %s", level, questText)
                questLogTitle:SetText(questTextFormatted)
                questLogTitle.normalText:SetWidth(265 - questLogTitle.tag:GetStringWidth())
            end
        end
    end
end

-- Set the script for the main frame to handle events
QuestLogPlus:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        return self[event](self, ...)
    end
end)
