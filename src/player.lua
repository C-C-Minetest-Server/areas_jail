-- areas_jail/src/player.lua
-- Handle player mechanics
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
local logger = _int.logger:sublogger("player")

-- Minimal set of safe privs
_aj.jailed_privs = { interact = true, shout = true, }

-- A list of Luaentities safe to use player:set_detach()
local save_detach_entities = {}
if core.get_modpath("boats") then
    save_detach_entities["boats:boat"] = true
end
local function set_player_pos(player, pos)
    -- TODO: do for more mods

    local name = player:get_player_name()

    -- Check for save detachment
    local attachment = player:get_attach()
    if attachment then
        local luaentity = attachment:get_luaentity()
        if luaentity and save_detach_entities[luaentity.name] then
            player:set_detach()
        end
    end

    -- Check for advtrains attachment
    if core.global_exists("advtrains") then
        local train_id = advtrains.player_to_train_mapping[name]
        print(train_id)
        if train_id and advtrains.trains[train_id] then
            -- cf. advtrains/advtrains/trainlogic.lua in minetest.register_on_dieplayer
            for _, wagon in pairs(core.luaentities) do
                print(wagon.is_wagon, wagon.train_id)
                if wagon.is_wagon and wagon.initialized then
                    -- For some reason wagon.train_id == train_id does not work
                    wagon:get_off_plr(name)
                end
            end
        end
    end

    player_api.set_animation(player, "stand", 30)
    player:set_pos(pos)
end

function _aj.get_player_jail(player)
    local meta = player:get_meta()

    local jail = meta:get_string("areas_jail_in")
    if jail == "" then return nil end
    if not _data[jail] then
        local name = player:get_player_name()
        logger:action(("Player %s jailed in nonexist jail, moving them out."):format(name))
        _aj.leave_jail(player)
    end

    return jail
end

function _aj.put_into_jail(player, id)
    if not _data[id] then return false end

    local name = player:get_player_name()
    logger:action(("Putting player %s into jail %s."):format(
        name, id
    ))

    local meta = player:get_meta()

    local old_pos = player:get_pos()
    meta:set_string("areas_jail_old_pos", core.pos_to_string(old_pos))

    meta:set_string("areas_jail_in", id)

    local spawnpoint = _data[id].spawnpoint
    set_player_pos(player, spawnpoint)

    local privs = core.get_player_privs(name)
    local privs_s = core.serialize(privs)
    meta:set_string("areas_jail_orig_privs", privs_s)

    core.set_player_privs(name, _aj.jailed_privs)
end

function _aj.leave_jail(player) -- Does not handle teleportion
    local name = player:get_player_name()
    logger:action(("Taking player %s out of jail."):format(name))

    local meta = player:get_meta()
    meta:set_string("areas_jail_in", "")

    local privs_s = meta:get_string("areas_jail_orig_privs")
    if privs_s == "" then return end
    local privs = core.deserialize(privs_s, true)
    core.set_player_privs(name, privs)
    meta:set_string("areas_jail_orig_privs", "")

    meta:set_string("areas_jail_old_pos", "")
end

function _aj.find_restore_pos(player)
    -- Step of checking
    -- 1. Static Spawn
    -- 2. /home position (requires sethome)
    -- 3. The saved areas_jail_old_pos (may be not safe so we put this last)
    -- 4. Leave them inside the jail (but they are theoretically free to leave)

    local spawn_pos = core.setting_get_pos("static_spawnpoint")
    if spawn_pos then return spawn_pos end

    local name = player:get_player_name()

    if core.global_exists("sethome") then
        local home_pos = sethome.get(name)
        if home_pos then return home_pos end
    end

    if core.global_exists("unified_inventory") then
        local home_pos = unified_inventory.home_pos[name]
        if home_pos then return home_pos end
    end

    local old_pos_s = meta:get_string("areas_jail_old_pos")
    if old_pos_s ~= "" then
        local old_pos = core.string_to_pos(old_pos_s)
        if old_pos then return old_pos end
    end

    return nil
end

local passed = 0
core.register_globalstep(function(dtime)
    passed = passed + dtime
    if passed < 0.4 then return end
    passed = 0

    for _, player in ipairs(core.get_connected_players()) do
        local jail = _aj.get_player_jail(player)
        if jail then
            local pos = player:get_pos()
            if not _aj.is_in_jail(pos, jail) then
                local spawnpoint = _data[jail].spawnpoint

                local name = player:get_player_name()
                local spawnpoint_str = core.pos_to_string(spawnpoint)

                logger:action(("Player %s found outside of jail %s, teleportig back to %s."):format(
                    name, jail, spawnpoint_str
                ))

                set_player_pos(player, spawnpoint)
            end
        end
    end
end)

core.register_on_respawnplayer(function(player)
    local jail = _aj.get_player_jail(player)
    if jail then
        local spawnpoint = _data[jail].spawnpoint
        local name = player:get_player_name()
        local spawnpoint_str = core.pos_to_string(spawnpoint)
        logger:action(("Player %s respawned while in jail %s, teleportig back to %s."):format(
            name, jail, spawnpoint_str
        ))

        set_player_pos(player, spawnpoint)

        return true
    end
end)
