-- areas_jail/init.lua
-- Manage jails using area protection
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

areas_jail = {}
areas_jail.internal = {}
areas_jail.internal.logger = logging.logger("areas_jail")
areas_jail.internal.S = core.get_translator("areas_jail")

local MP = core.get_modpath("areas_jail")
for _, name in ipairs({
    "storage",
    "api",
    "player",
    "chatcommands",
}) do
    dofile(MP .. "/src/" .. name .. ".lua")
end

areas_jail.internal = nil
