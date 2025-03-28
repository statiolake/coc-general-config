local M = {}

local function read_json_file(filepath)
  local file = io.open(filepath, "r")
  if not file then return nil end
  local content = file:read("*a")
  file:close()
  return vim.fn.json_decode(content)
end

local function merge_configs(high_priority, low_priority)
  local result = vim.deepcopy(low_priority)
  for k, v in pairs(high_priority) do
    result[k] = v
  end
  return result
end

function M.get(path)
  -- Check if coc.nvim is initialized
  if vim.g.coc_service_initialized == 1 then
    return vim.fn["coc#util#get_config"](path)
  end

  -- Parse configurations manually
  local user_config = vim.g.coc_user_config or {}
  local global_config_path = vim.g.coc_config_home and (vim.g.coc_config_home .. "/coc-settings.json")
    or (vim.fn.stdpath("config") .. "/coc-settings.json")
  local workspace_config_path = ".vim/coc-settings.json"

  local global_config = read_json_file(global_config_path) or {}
  local workspace_config = read_json_file(workspace_config_path) or {}

  -- Merge configurations: user_config > workspace_config > global_config
  local merged_config = merge_configs(global_config, workspace_config)
  merged_config = merge_configs(merged_config, user_config)

  -- Remove filetype-specific settings
  for key, _ in pairs(merged_config) do
    if key:match("^%[.*%]$") then
      merged_config[key] = nil
    end
  end

  -- Extract settings based on the path
  if path then
    local result = {}
    local path_pattern = "^" .. vim.pesc(path) .. "%.(.+)$"

    for key, value in pairs(merged_config) do
      if key == path then
        return value -- Exact match
      end

      local stripped_key = key:match(path_pattern)
      if stripped_key then
        result[stripped_key] = value
      end
    end

    if next(result) then
      return result
    end
    return nil -- No matches found for the path
  end

  return merged_config
end

function M.set(path, value)
  -- coc#config() is always available
  return vim.fn['coc#config'](path, value)
end

function M.access(path, value)
  if value == nil then
    return M.get(path)
  else
    return M.set(path, value)
  end
end

return M
