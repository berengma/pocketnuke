
local chat = true               -- status messages on/off

local fuel_max_charge = 650000 * 25 -- Max value for one uranium rod

local ocs = core.colorize('#eeee00', " >>> ")
local ccs = core.colorize('#eeee00', " <<< ")
local nukestring = ocs.."OK"..ccs

local function pocket_update(player_name)
	minetest.show_formspec(player_name, "pocketnuke:theform",
				"size[8,8]" ..
				"image[0.5,0;5,3;pocketnuke_warning.png]"..
				"label[0,3.2;Status:"..nukestring.."]"..
				"list[detached:"..player_name.."_pocketnuke;fuel;6.5,0.5;1,1;]"..
				"label[5.5,1;Fuel]"..
				"list[detached:"..player_name.."_pocketnuke;machine;6.5,2;1,1;]"..
				"label[5.5,2.5;Tool]"..
				"list[current_player;main;0,4;8,4;]")
end

minetest.register_tool("pocketnuke:uranium_fuel", {   -- This is a trick to be able to show a wearout bar
	description = "PocketNuke Uranium Fuel",
	inventory_image = "technic_uranium_fuel.png",
	groups = {not_in_creative_inventory=1},           -- no need to see in inventory
	tool_capabilities = {
		max_drop_level=0,
		groupcaps= {
			cracky={times={[1]=4.00, [2]=1.50, [3]=1.00}, uses=70, maxlevel=1} -- useless here but part of definition
		}
	}
})

unified_inventory.register_button("nuke", {
	type = "image",
	image = "pocketnuke.png",
	tooltip = "Pocket Nuke",
	action = function(player)
		local player_name = player:get_player_name()
		if not player_name then return end
		nukestring = ocs.."OK"..ccs
		pocket_update(player_name)
	end
})

local pocket_charge_tool
if technic.plus then
	function pocket_charge_tool(inv, stack, stackname, player_inv)
		local fuelstack = player_inv:get_stack("fuel", 1)
		local fuelmeta = minetest.deserialize(fuelstack:get_metadata()) or {}
		local max_charge = stack:get_definition().technic_max_charge or 0
		local charge = technic.get_RE_charge(stack)
		local need = max_charge - charge
		charge = charge + (need >= fuelmeta.fuel and fuelmeta.fuel or need)
		fuelmeta.fuel = fuelmeta.fuel - need
		fuelstack:set_wear(65535-(fuelmeta.fuel/fuel_max_charge*65535)) -- update fuel wearout
		technic.set_RE_charge(stack, charge)
		fuelstack:set_metadata(minetest.serialize(fuelmeta))
		if fuelmeta.fuel <= 0 then
			fuelstack = {}
		end
		player_inv:set_stack("fuel", 1, fuelstack)
		inv:set_stack("fuel", 1, fuelstack)
	end
else
	function pocket_charge_tool(inv, stack, stackname, player_inv)
		local fuelstack = player_inv:get_stack("fuel", 1)
		local fuelmeta = minetest.deserialize(fuelstack:get_metadata()) or {}
		local meta = minetest.deserialize(stack:get_metadata()) or {}
		local max_charge = technic.power_tools[stackname] or 0
		if not meta or not meta.charge then
			meta.charge = 0
		end
		local need = max_charge	- meta.charge
		if need >= fuelmeta.fuel then
			meta.charge = meta.charge + fuelmeta.fuel
			fuelmeta.fuel = fuelmeta.fuel - need
		else
			meta.charge = meta.charge + need
			fuelmeta.fuel = fuelmeta.fuel - need
		end
		fuelstack:set_wear(65535-(fuelmeta.fuel/fuel_max_charge*65535)) -- update fuel wearout
		technic.set_RE_wear(stack, meta.charge, max_charge)             -- update tool charge
		stack:set_metadata(minetest.serialize(meta))
		fuelstack:set_metadata(minetest.serialize(fuelmeta))
		if fuelmeta.fuel <= 0 then
			fuelstack = {}
		end
		player_inv:set_stack("fuel", 1, fuelstack)
		inv:set_stack("fuel", 1, fuelstack)
	end
end

local pocket_inv_definition = {
	allow_put = function(nuke_inv, listname, index, stack, player)
		local stackname = stack:get_name()
		local name = player:get_player_name()
		local player_inv = player:get_inventory()
		if listname == "fuel" then -- check if uranium already inside or wrong fuel
			if stackname == "technic:uranium_fuel" and not nuke_inv:contains_item("fuel", "pocketnuke:uranium_fuel") then
				return 1
			else
				if chat then
					--minetest.chat_send_player(name, ocs.."Wrong fuel or place is taken"..ccs)
					nukestring = ocs.."Wrong fuel or place is taken"..ccs
					pocket_update(name)
				end
				return 0
			end
		end
		if listname == "machine" then
			if not technic.power_tools[stackname] then
				if chat then
					--minetest.chat_send_player(name, ocs.."This is not rechargeable"..ccs)
					nukestring = ocs.."This is not rechargeable"..ccs
					pocket_update(name)
				end
				return 0
			end
			local fuelstack = player_inv:get_stack("fuel", 1)
			if fuelstack:get_name() ~= "pocketnuke:uranium_fuel" then
				if chat then
					--minetest.chat_send_player(name, ocs.."You need uranium fuel first"..ccs)
					nukestring = ocs.."You need uranium fuel first"..ccs
					pocket_update(name)
				end
				return 0
			else
				return 1
			end
		end
	end,
	allow_take = function(inv, listname, index, stack, player)
		local name = player:get_player_name()
		if listname == "fuel" then
			if chat then
				--minetest.chat_send_player(name, ocs.."Do not touch it, its radioactive"..ccs)
				nukestring = ocs.."Do not touch it, its radioactive"..ccs
				pocket_update(name)
			end
			return 0
		end
		return stack:get_count()
	end,
	-- Moving across pocketnuclear is not allowed
	allow_move = function(inv, listname, index, stack, player)
		return 0
	end,
	on_put = function(inv, listname, index, stack, player)
		local player_inv = player:get_inventory()
		local name = player:get_player_name()
		local stackname = stack:get_name()
		if listname == "fuel" then
			stack:replace("pocketnuke:uranium_fuel 1")			-- put the tool for the wearoutbar
			local meta = minetest.deserialize(stack:get_metadata()) or {}
			if not meta.fuel then
				meta.fuel = fuel_max_charge
			end
			stack:set_wear(65535/(meta.fuel+1))
			stack:set_metadata(minetest.serialize(meta))            -- initialize waerout
		end
		if listname == "machine" then
			pocket_charge_tool(inv, stack, stackname, player_inv)
			nukestring = ocs.."OK"..ccs
			pocket_update(name)
		end
		player_inv:set_stack(listname, index, stack)
		inv:set_stack(listname, index, stack)
	end,
	on_take = function(inv, listname, index, stack, player)
		if listname == "machine" then
			stack:take_item(stack:get_count())
			local player_inv = player:get_inventory()
			player_inv:set_stack(listname,index,stack)
			return stack:get_count()
		else
			return 0
		end
	end,
}

minetest.register_on_joinplayer(function(player)
	local player_inv = player:get_inventory()
	local player_name = player:get_player_name()
	local nuke_inv = minetest.create_detached_inventory(player_name.."_pocketnuke", pocket_inv_definition, player_name)
	nuke_inv:set_size("fuel", 1)
	nuke_inv:set_size("machine", 1)
	player_inv:set_size("fuel", 1)
	player_inv:set_size("machine", 1)
	nuke_inv:set_stack("fuel", 1, player_inv:get_stack("fuel", 1))         -- load stuff to inventory
	nuke_inv:set_stack("machine", 1, player_inv:get_stack("machine", 1))   -- load stuff to inventory
end)
