-- Declare addon name and namespace
local addOnName, ns = ...

-- Create a cache for quest data
local questCache = {}
-- Define the level cap
local LEVEL_CAP = 80
-- Initialize addon data
local addonData
local defaultSavedVariables = {
    QXPdb = {},
}

-- Create the main frame for the addon
local QuestLogPlus = CreateFrame("FRAME")
QuestLogPlus:RegisterEvent("ADDON_LOADED")

-- Event handler for ADDON_LOADED event
function QuestLogPlus:ADDON_LOADED(loadedAddOnName)
    -- Check if the loaded addon is the intended one
    if loadedAddOnName == addOnName then
        -- Initialize SavedVariables
        if not QXPdb then
            QXPdb = {}
        end
        addonData = QXPdb

        -- Register events for quest-related actions
        QuestLogPlus:RegisterEvent("QUEST_DETAIL")
        QuestLogPlus:RegisterEvent("QUEST_ACCEPTED")
        QuestLogPlus:RegisterEvent("QUEST_REMOVED")

        -- Hook into the QuestLog_Update function to customize quest display
        hooksecurefunc("QuestLog_Update", function()
            QuestLogPlus:QuestLog_Update("QuestLog")
        end)

        -- Hook into QuestLogListScrollFrame's update method
        hooksecurefunc(QuestLogListScrollFrame, "update", function()
            QuestLogPlus:QuestLog_Update("QuestLog")
        end)

        -- Support for QuestLogEx addon
        if QuestLogEx then
            hooksecurefunc("QuestLog_Update", function()
                QuestLogPlus:QuestLog_Update("QuestLogEx")
            end)
        end

        -- Hook into OnUpdate for additional quest level updates
        QuestLogFrame:HookScript('OnUpdate', function()
            QuestLogPlus:UpdateQuestLevels()
        end)
    end
end

-- Event handler for QUEST_DETAIL event
function QuestLogPlus:QUEST_DETAIL()
    local questID = GetQuestID()
    local questXP = GetRewardXP()

    -- Cache quest XP if the ID and XP are valid
    if questID > 0 and questXP > 0 then
        questCache[questID] = {
            XP = questXP
        }
    end
end

-- Event handler for QUEST_ACCEPTED event
function QuestLogPlus:QUEST_ACCEPTED(questIndex, questID)
    -- If the quest data is in the cache, add it to the addon data
    if questCache[questID] then
        addonData[questID] = questCache[questID]
    else
        -- If not in the cache, retrieve quest XP and add it to the addon data
        local questXP = GetRewardXP()
        if questXP > 0 then
            addonData[questID] = {
                XP = questXP
            }
        end
    end
end

-- Event handler for QUEST_REMOVED event
function QuestLogPlus:QUEST_REMOVED(questID)
    -- Remove quest data from addon data
    addonData[questID] = nil
end

-- Function to update the quest log display
function QuestLogPlus:QuestLog_Update(addonName)
    -- Variables for quest display customization
    local headerXP = {}
    local header
    local xpLevelTag = 'xp'

    -- Check player's level for tag customization
    if UnitLevel("player") == LEVEL_CAP then
        xpLevelTag = '**'
    end

    -- Get the number of quest log entries and quests
    local numEntries, numQuests = GetNumQuestLogEntries();
    local scrollOffset = HybridScrollFrame_GetOffset(QuestLogListScrollFrame);
    local buttons = QuestLogListScrollFrame.buttons;
    local buttonHeight = buttons[1]:GetHeight();
    local displayedHeight = 0;

    -- Variables for quest display details
    local questIndex, questLogTitle, questTitleTag, questNumGroupMates, questNormalText, questHighlight, questCheck;
    local questLogTitleText, level, questTag, isHeader, isCollapsed, isComplete, color;
    local numPartyMembers, partyMembersOnQuest, tempWidth, textWidth;

    -- Determine the number of quests to be displayed based on the addon
    local numQuestsDisplayed
    if addonName == "QuestLogEx" then
        numQuestsDisplayed = QuestLogEx.db.global.maxQuestsDisplayed
    else
        numQuestsDisplayed = QUESTS_DISPLAYED
    end

    -- Iterate over quests to customize their display
    for i=1, numQuestsDisplayed, 1 do
        questLogTitle = buttons[i];
        questIndex = i + scrollOffset;
        questLogTitle:SetID(questIndex);
        questTitleTag = questLogTitle.tag;
        questNumGroupMates = questLogTitle.groupMates;
        questCheck = questLogTitle.check;
        questNormalText = questLogTitle.normalText

        -- Get quest information for the current button
        if ( questIndex <= numEntries ) then
            questLogTitleText, level, questTag, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling = GetQuestLogTitle(questIndex);

            -- Set the quest tag
            if ( isComplete and isComplete < 0 ) then
                questTag = FAILED;
            elseif ( isComplete and isComplete > 0 ) then
                questTag = COMPLETE;
            elseif ( frequency == LE_QUEST_FREQUENCY_DAILY ) then
                if ( questTag ) then
                    questTag = format(DAILY_QUEST_TAG_TEMPLATE, questTag);
                else
                    questTag = DAILY;
                end
            end

            -- Customize quest title tag based on data availability
            if ( questTag ) then
                if QXPdb[questID] then
                    questTitleTag:SetText(string.format("%d%s (%s)", QXPdb[questID].XP, xpLevelTag, questTag));
                else
                    questTitleTag:SetText("("..questTag..")");
                end
                -- Shrink text to accommodate quest tags without wrapping
                tempWidth = 275 - 15 - questTitleTag:GetWidth();

                if ( QuestLogDummyText:GetWidth() > tempWidth ) then
                    textWidth = tempWidth;
                else
                    textWidth = QuestLogDummyText:GetWidth();
                end
                questNormalText:SetWidth(tempWidth);
                -- If there's a quest tag position check accordingly
                questTitleTag:Show();
                --questCheck:Hide();
            else
                -- Customize quest title tag based on data availability
                if QXPdb[questID] then
                    questTitleTag:SetText(string.format("%d%s", QXPdb[questID].XP, xpLevelTag));

                    -- Shrink text to accommodate quest tags without wrapping
                    tempWidth = 275 - 15 - questTitleTag:GetWidth();

                    if ( QuestLogDummyText:GetWidth() > tempWidth ) then
                        textWidth = tempWidth;
                    else
                        textWidth = QuestLogDummyText:GetWidth();
                    end
                    questNormalText:SetWidth(tempWidth);
                    -- If there's a quest tag position check accordingly
                    questTitleTag:Show();
                    --questCheck:Hide();
                else
                    questTitleTag:SetText("");
                end
            end

            -- Resize the quest log title button
            QuestLogTitleButton_Resize(questLogTitle)
        end
    end
end

-- Function to update quest levels
function QuestLogPlus:UpdateQuestLevels()
    local numEntries, numQuests = GetNumQuestLogEntries()

    -- Return if there are no quest entries
    if (numEntries == 0) then return end

    -- Variables for quest level update
    local questIndex, questLogTitle, title, level, _, isHeader, questTextFormatted, questCheck

    -- Iterate over displayed quests to update levels
    for i = 1, _G.QUESTS_DISPLAYED, 1 do
        questIndex = i + FauxScrollFrame_GetOffset(QuestLogListScrollFrame)

        if (questIndex <= numEntries) then
            questLogTitle = _G["QuestLogListScrollFrameButton"..i]
            questCheck = _G["QuestLogListScrollFrameButton"..i.."Check"]
            title, level, _, isHeader = GetQuestLogTitle(questIndex)

            -- If it's not a header, format and display quest level
            if (not isHeader) then
                questTextFormatted = format("[%d] %s", level, title)
                questLogTitle:SetText(questTextFormatted)
                questLogTitle.normalText:SetWidth(265 - _G["QuestLogListScrollFrameButton"..i.."Tag"]:GetStringWidth())
                questCheck:SetPoint("LEFT", questLogTitle, "LEFT", questLogTitle.normalText:GetStringWidth() + 18, 0)
                questCheck:SetVertexColor(64/255, 224/255, 208/255)
                questCheck:SetDrawLayer("ARTWORK")
            else
                -- Hide check for header entries
                questCheck:Hide()
            end
        end
    end
end

-- Set the script for the main frame to handle events
QuestLogPlus:SetScript("OnEvent", function (self, event, ...)
    if self[event] then
        return self[event](self, ...)
    end

    -- Save changes to SavedVariables when the player logs out
    if event == "PLAYER_LOGOUT" then
        QXPdb = addonData
    end
end)
