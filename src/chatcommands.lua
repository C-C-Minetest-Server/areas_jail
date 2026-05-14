-- areas_jail/src/chatcommands.lua
-- Chatcommand for dealing with jails
--[[
    areas_jail: Manage jails using area protection
    Copyright (C) 2024  1F616EMO

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
]]

local _aj = areas_jail
local _int = _aj.internal
local _data = _aj.jail_data
local logger = _int.logger:sublogger("chatcommands")

local S = _int.S

_aj.chatcommand_privs = { ban = true, }

core.register_chatcommand("jail", {
    description = S("Put a player into a jail"),
    params = S("<player> <jail ID>"),
    privs = _aj.chatcommand_privs,
    func = function(name, param)
        local params = string.split(param, " ", false, 1)
        if not params[2] then
            return false, S("Invalid usage, see /help @1", "jail")
        end
        local pname, jail = params[1], params[2]

        if name == pname and not core.settings:get_bool("areas_jail.allow_self_jailing", false) then
            return false, S("You don't want to jail yourselves, right?")
        end

        local player = core.get_player_by_name(pname)
        if not player then
            return false, S("Player @1 is not online.", pname)
        end

        if not _data[jail] then
            return false, S("Jail @1 does not exist.", jail)
        end

        logger:action(("Player %s put %s into jail %s."):format(name, pname, jail))
        _aj.put_into_jail(player, jail)

        core.chat_send_player(pname,
            S("You have been jailed. Reflect on your mistakes, and ask moderators for more information."))

        return true, S("Put @1 into jail @2.", pname, jail)
    end,
})

core.register_chatcommand("unjail", {
    description = S("Move a player out of jail"),
    params = S("<player>"),
    privs = _aj.chatcommand_privs,
    func = function(name, param)
        local player = core.get_player_by_name(param)
        if not player then
            return false, S("Player @1 is not online.")
        end

        logger:action(("Player %s moved %s out of jail."):format(name, param))

        core.chat_send_player(param,
            S("You have been moved out of jail. Do not make the same mistake again."))

        local spawn_pos = _aj.find_restore_pos(player)
        if spawn_pos then
            player:set_pos(spawn_pos)
        else
            core.chat_send_player(param,
                S("Failed to reset your position. Try using /home to go back."))
        end

        -- Don't worry, position check can't occur mid-execution
        -- So we put this behind to retain meta for finding spawn pos
        _aj.leave_jail(player)

        return true, S("Moved @1 out of jail.", param)
    end,
})

core.register_chatcommand("jailset", {
    description = S("Set or add the properties of a jail"),
    params = S("<jail ID> <area IDs> <spawnpoint>"),
    privs = _aj.chatcommand_privs,
    func = function(name, param)
        local params = string.split(param, " ", false, 2)
        if not params[3] then
            return false, S("Invalid usage, see /help @1", "jailset")
        end

        local jail, area_ids_s, spawnpoint_s = params[1], params[2], params[3]
        local area_ids_st, area_ids = string.split(area_ids_s), {}

        for i, id_s in ipairs(area_ids_st) do
            local id = tonumber(id_s)
            if not areas.areas[id] then
                return false, S("Area @1 does not exist.", id_s)
            end
            area_ids[i] = id
        end

        local spawnpoint = core.string_to_pos(spawnpoint_s)
        if not spawnpoint then
            return false, S("Invalid usage, see /help @1", "jailset")
        end

        if not _aj.is_in_areas(spawnpoint, area_ids) then
            return false, S("The spawnpoint must be located inside the areas.")
        end

        logger:action(("Player %s set jail %s to areas %s and spawnpoint %s"):format(
            name, jail, area_ids_s, spawnpoint_s
        ))
        _aj.set_jail(jail, area_ids, spawnpoint)

        return true, S("Jail set.")
    end
})

core.register_chatcommand("jailunset", {
    description = S("Unset a jail"),
    params = S("<jail ID>"),
    privs = _aj.chatcommand_privs,
    func = function(name, param)
        _aj.unset_jail(param)
        return true, S("Jail unset.")
    end,
})

core.register_chatcommand("jaillist", {
    description = S("List all jails"),
    privs = _aj.chatcommand_privs,
    func = function(name, param)
        local rstr = "-- " .. S("Jail list start") .. " --"
        for id, data in pairs(_data) do
            rstr = rstr .. "\n" .. id .. " " ..
                table.concat(data.areas, ",") .. " " ..
                core.pos_to_string(data.spawnpoint)
        end
        rstr = rstr .. "\n-- " .. S("Jail list end") .. " --"

        return true, rstr
    end,
})
