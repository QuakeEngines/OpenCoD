
-- WolfAdmin module for Wolfenstein: Enemy Territory servers.
-- Copyright (C) 2015-2017 Timo 'Timothy' Smit

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- at your option any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

local auth = require (wolfa_getLuaPath()..".auth.auth")

local players = require (wolfa_getLuaPath()..".players.players")

local constants = require (wolfa_getLuaPath()..".util.constants")
local util = require (wolfa_getLuaPath()..".util.util")
local events = require (wolfa_getLuaPath()..".util.events")
local settings = require (wolfa_getLuaPath()..".util.settings")
local files = require (wolfa_getLuaPath()..".util.files")

local toml = require "toml"

local greetings = {}

local userGreetings = {}
local levelGreetings = {}

function greetings.get(clientId)
    local lvl = auth.getPlayerLevel(clientId)
    
    if not auth.isPlayerAllowed(clientId, auth.PERM_INCOGNITO) then
        if userGreetings[players.getGUID(clientId)] ~= nil then
            return userGreetings[players.getGUID(clientId)]
        elseif levelGreetings[lvl] ~= nil then
            return levelGreetings[lvl]
        end
    else
        if levelGreetings[0] then
            return levelGreetings[0]
        end
    end
end

function greetings.show(clientId)
    local greeting = greetings.get(clientId)
    
    if greeting then
        local prefix = (util.getAreaName(settings.get("g_greetingArea")) ~= "cp") and "^dgreeting: ^9" or "^7"
        local text = prefix..greeting["text"]:gsub("%[N%]", et.gentity_get(clientId, "pers.netname"))
        local out = ""
        
        while util.getAreaName(settings.get("g_greetingArea")) == "cp" and string.len(text) > constants.MAX_LENGTH_CP do
            local sub = text:sub(1, constants.MAX_LENGTH_CP)
            local rev = sub:reverse()

            local pos = rev:find(" [^^]") -- some epic smiley exclusion here

            if pos then
                pos = constants.MAX_LENGTH_CP - pos
                out = out..text:sub(1, pos).."\\n"
                text = text:sub(pos + 2)
            else
                pos = sub:len()
                out = out..text:sub(1, pos).."\\n"
                text = text:sub(pos + 1)
            end
        end
        
        if greeting["sound"] then
            et.trap_SendConsoleCommand(et.EXEC_APPEND, "playsound \"/sound/"..greeting["sound"].."\";")
        end
        
        et.trap_SendConsoleCommand(et.EXEC_APPEND, util.getAreaName(settings.get("g_greetingArea")).." \""..out..text.."\";")
    end
end

function greetings.load()
    local fileName = settings.get("g_fileGreetings")

    if fileName == "" then
        return 0
    end

    if string.find(fileName, ".toml") == string.len(fileName) - 4 then
        local fileDescriptor, fileLength = et.trap_FS_FOpenFile(fileName, et.FS_READ)
        local fileString = et.trap_FS_Read(fileDescriptor, fileLength)

        et.trap_FS_FCloseFile(fileDescriptor)

        local fileTable = toml.parse(fileString)

        for _, greeting in ipairs(fileTable["level"]) do
            if greeting["greeting"] then
                levelGreetings[greeting["level"]] = {
                    ["text"] = greeting["greeting"],
                    ["sound"] = greeting["sound"]
                }
            end
        end

        for _, greeting in ipairs(fileTable["user"]) do
            if greeting["greeting"] then
                userGreetings[greeting["guid"]] = {
                    ["text"] = greeting["greeting"],
                    ["sound"] = greeting["sound"]
                }
            end
        end

        return #fileTable["level"] + #fileTable["user"]
    else
        -- compatibility for 1.1.* and lower
        outputDebug("Using .cfg files is deprecated as of 1.2.0. Please consider updating to .toml files.", 3)

        local amount, array = files.loadFromCFG(fileName, "[a-z]+")

        for _, greeting in ipairs(array["level"]) do
            if greeting["text"] then
                levelGreetings[tonumber(greeting["level"])] = {
                    ["text"] = greeting["greeting"],
                    ["sound"] = greeting["sound"]
                }
            end
        end

        for _, greeting in ipairs(array["user"]) do
            if greeting["text"] then
                userGreetings[greeting["guid"]] = {
                    ["text"] = greeting["greeting"],
                    ["sound"] = greeting["sound"]
                }
            end
        end

        return amount
    end

    return 0
end

function greetings.oninit(levelTime, randomSeed, restartMap)
    if settings.get("g_fileGreetings") ~= "" then
        greetings.load()
        
        events.handle("onPlayerReady", greetings.onready)
    end
end
events.handle("onGameInit", greetings.oninit)

function greetings.onready(clientId, firstTime)
    if firstTime and (not players.isBot(clientId) or settings.get("g_botGreetings") == 1) then
        greetings.show(clientId)
    end
end

return greetings
