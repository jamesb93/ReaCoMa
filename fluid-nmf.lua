local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
dofile(script_path .. "FluidUtils.lua")
dofile(script_path .. "FluidParams.lua")

------------------------------------------------------------------------------------
--   Each user MUST point this to their folder containing FluCoMa CLI executables --
if sanity_check() == false then goto exit; end
local cli_path = get_fluid_path()
--   Then we form some calls to the tools that will live in that folder --
local nmf_suf = cli_path .. "/fluid-nmf"
local nmf_exe = doublequote(nmf_suf)
------------------------------------------------------------------------------------

local num_selected_items = reaper.CountSelectedMediaItems(0)
if num_selected_items > 0 then

    -- Parameter Get/Set/Prep
    local processor = fluid_archetype.nmf
    check_params(processor)
    local param_names = "components,iterations,fftsettings"
    local param_values = parse_params(param_names, processor)
    
    local confirm, user_inputs = reaper.GetUserInputs("NMF Parameters", 3, param_names, param_values)
    if confirm then
        store_params(processor, param_names, user_inputs)

        reaper.Undo_BeginBlock()
        -- Algorithm Parameters
        local params = commasplit(user_inputs)
        local components = params[1]
        local iterations = params[2]
        local fftsettings = params[3]
        local identifier = rmdelim(components .. iterations .. fftsettings)

        local item_t = {}
        local nmf_cmd_t = {}
        local components_t = {}

        for i=1, num_selected_items do

            local item = reaper.GetSelectedMediaItem(0, i-1)
            local take = reaper.GetActiveTake(item)
            local src = reaper.GetMediaItemTake_Source(take)
            local sr = reaper.GetMediaSourceSampleRate(src)
            local full_path = reaper.GetMediaSourceFileName(src, '')
            table.insert(item_t, item)
            
            local take_ofs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
            local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

            -- Now make the name for the component.wav using the offset to create a unique id --
            -- Using the offset means that slices won't share names at the output in the situation where you nmf on segments --
            table.insert(components_t, basename(full_path) .. "_nmf_" .. tostring(take_ofs) .. identifier .. ".wav")

            local take_ofs_samples = stosamps(take_ofs, sr)
            local item_pos_samples = stosamps(item_pos, sr)
            local item_len_samples = stosamps(item_len, sr)

            table.insert(
                nmf_cmd_t, 
                nmf_exe .. 
                " -source " .. doublequote(full_path) .. " -resynth " .. doublequote(components_t[i]) ..  
                " -numframes " .. item_len_samples .. " -startframe " .. take_ofs_samples .. 
                " -components " .. components .. " -fftsettings " .. fftsettings
            )
        end

        -- Execute NMF Process
        for i=1, num_selected_items do
            cmdline(nmf_cmd_t[i])
        end
        reaper.SelectAllMediaItems(0, 0)
        for i=1, num_selected_items do
            if i > 1 then reaper.SetMediaItemSelected(item_t[i-1], false) end
            reaper.SetMediaItemSelected(item_t[i], true)
            reaper.InsertMedia(components_t[i],3)    
        end
        reaper.UpdateArrange()
        reaper.Undo_EndBlock("NMF", 0)
    end
end
::exit::