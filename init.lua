local S = minetest.get_translator("bag")
local N = function(s) return s end

local storage = minetest.get_mod_storage()
local bag_width = 7
local bag_height = 3

local function table_to_inventory(table, inv)
	for listname, list in pairs(table) do
		for i, stack in pairs(list) do
			inv:set_stack(listname, i, stack)
		end
	end
end

local function inventory_to_table(inv)
	local table = {}
	for listname, list in pairs(inv:get_lists()) do
		local size = inv:get_size(listname)
		if size then
			table[listname] = {}
			for i = 1, size, 1 do
				table[listname][i] = inv:get_stack(listname, i):to_table()
			end
		end
	end
	return table
end

local function generateBagId()
    local id = storage:get_int("bag_id")
    storage:set_int("bag_id", id + 1)
    return "bag_" .. tostring(id)
end

local function have_bag(bagId, player)
    local playerInv = player:get_inventory()
    for i = 1, playerInv:get_size("main") do
        local stack = playerInv:get_stack("main", i)
        local meta = stack:get_meta()
        local bagIdMeta = meta:get_string("bag_id")
        if bagIdMeta == bagId then
            return true, stack, i
        end
    end
    return false
end

-----------------
-- Save
-----------------

local function save_bag_player(itemstack, player)
    local playerInv = player:get_inventory()
    local bagId = itemstack:get_meta():get_string("bag_id")

    local haveBag, bagStack, index = have_bag(bagId, player)
    if haveBag then
        playerInv:set_stack("main", index, itemstack)
    end
end

local function save_bag(inv, itemstack, player)
    local meta = itemstack:get_meta()
    local table = inventory_to_table(inv)
    meta:set_string("bag_content", minetest.serialize(table))
    save_bag_player(itemstack, player)
    return itemstack
end

-----------------
-- Formspec
-----------------

local function get_formspec(bagId)
    local formspec_width = 8
    local formspec_height = bag_height + 4.75
    local detached_inv_pos = (formspec_width - bag_width) / 2
    if bag_width > 8 then
        formspec_width = bag_width
        detached_inv_pos = 0
    end

    local formspec = "size[" .. formspec_width .. "," .. formspec_height .. "]" ..
        "list[detached:" .. bagId .. ";main;" .. detached_inv_pos .. ",0;" .. bag_width .. "," .. bag_height .. ";]" ..
        "list[current_player;main;" .. (formspec_width - 8) / 2 .. "," .. bag_height + 0.75 .. ";8,4;]" ..
        "listring[detached:" .. bagId .. ";main]" ..
        "background[-0.5,-0.5;9,9;background.png]" ..
        "listring[current_player;main]"

    return formspec
end

local function open_bag(player, itemstack)
    local meta = itemstack:get_meta()
    local bagId = meta:get_string("bag_id")
    if not bagId  or bagId == "" then
        bagId = generateBagId()
        meta:set_string("bag_id", bagId)

        if not have_bag(bagId, player) then
            local playerInv = player:get_inventory()
            for i = 1, playerInv:get_size("main") do
                local stack = playerInv:get_stack("main", i)
                if stack:get_name() == "bag:bag" and stack:get_meta():get_string("bag_id") == "" then
                    stack:get_meta():set_string("bag_id", bagId)
                    playerInv:set_stack("main", i, stack)
                end
            end
        end

    end

    local inv = minetest.create_detached_inventory(bagId, {
        on_put = function(inv, listname, index, stack, player)
            stack = save_bag(inv, itemstack, player)
        end,
        on_take = function(inv, listname, index, stack, player)
            save_bag(inv, itemstack, player)
        end,
        on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
            save_bag(inv, itemstack, player)
        end,
        allow_put = function(inv, listname, index, stack, player)
            if stack:get_name() == "bag:bag" or not have_bag(bagId, player) then
                return 0
            end
            return stack:get_count()
        end,
        allow_take = function(inv, listname, index, stack, player)
            if stack:get_name() == "bag:bag" or not have_bag(bagId, player) then
                return 0
            end
            return stack:get_count()
        end,
        allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
            if inv:get_stack(from_list, from_index):get_name() == "bag:bag" or not have_bag(bagId, player) then
                return 0
            end
            return count
        end,
    })
    inv:set_size("main", bag_width * bag_height)

    local content = meta:get_string("bag_content")
    if content ~= "" then
        local table = minetest.deserialize(content)
        table_to_inventory(table, inv)
    end

    minetest.show_formspec(player:get_player_name(), "bag_inventory", get_formspec(bagId))
        
    return itemstack
end

-----------------
-- Item
-----------------

minetest.register_craftitem("bag:bag", {
    description = S("Bag"),
    inventory_image = "bag.png",
    stack_max = 1,
    on_use = function(itemstack, user, pointed_thing)
        open_bag(user, itemstack)
    end,
})

minetest.register_craft({
    output = "bag:bag",
    recipe = {
        {"farming:string", "farming:string", "farming:string"},
        {"group:wool", "", "group:wool"},
        {"group:wool", "group:wool", "group:wool"}
    }
})
