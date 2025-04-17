local M = {}

local function read_json_file(filepath)
  local file = io.open(filepath, 'r')
  if not file then
    return nil
  end
  local content = file:read '*a'
  file:close()
  return vim.fn.json_decode(content)
end

local function unflatten_keys(tbl)
  -- テーブルでない場合は変換不要
  if type(tbl) ~= 'table' then
    return tbl
  end

  local result = {}
  for k, v in pairs(tbl) do
    local parts = {}
    -- キーをドットで分割
    for part in k:gmatch '[^%.]+' do
      table.insert(parts, part)
    end

    -- 入れ子構造を構築
    local current = result
    for i = 1, #parts - 1 do
      local part = parts[i]
      current[part] = current[part] or {}
      current = current[part]
    end
    current[parts[#parts]] = v
  end

  return result
end

local function merge_configs(high_priority, low_priority)
  local function deep_merge(target, source)
    if type(source) ~= 'table' then
      return source
    end
    if type(target) ~= 'table' then
      target = {}
    end
    for k, v in pairs(source) do
      target[k] = deep_merge(target[k], v)
    end
    return target
  end

  return deep_merge(vim.deepcopy(low_priority), high_priority)
end

function M.get(path)
  -- Check if coc.nvim is initialized
  if vim.g.coc_service_initialized == 1 then
    return vim.fn['coc#util#get_config'](path)
  end

  -- Parse configurations manually
  local user_config = unflatten_keys(vim.g.coc_user_config) or {}

  local global_config_path = vim.g.coc_config_home
      and (vim.g.coc_config_home .. '/coc-settings.json')
    or (vim.fn.stdpath 'config' .. '/coc-settings.json')
  local global_config = unflatten_keys(read_json_file(global_config_path))
    or {}

  local workspace_config_path = '.vim/coc-settings.json'
  local workspace_config = unflatten_keys(
    read_json_file(workspace_config_path)
  ) or {}

  -- Merge configurations: user_config > workspace_config > global_config
  local merged_config = global_config
  merged_config = merge_configs(merged_config, workspace_config)
  merged_config = merge_configs(merged_config, user_config)

  -- Remove filetype-specific settings
  for key, _ in pairs(merged_config) do
    if key:match '^%[.*%]$' then
      merged_config[key] = nil
    end
  end

  -- Extract settings based on the path
  if not path then
    return merged_config
  end

  -- Split the path and traverse the configuration tree
  local parts = {}
  for part in path:gmatch '[^%.]+' do
    table.insert(parts, part)
  end

  local current = merged_config
  for _, part in ipairs(parts) do
    if type(current) ~= 'table' then
      return nil
    end
    current = current[part]
  end

  if type(current) ~= 'table' then
    -- NOTE: Not ideal but matches coc#util#get_config() behavior
    return nil
  end
  return current
end

function M.set(path, value)
  -- coc#config() is always available
  if vim.g.coc_service_initialized == 1 then
    return vim.fn['coc#config'](path, value)
  end

  -- Parse configurations manually
  local user_config = vim.g.coc_user_config or {}

  -- Split path into parts
  local parts = {}
  for part in path:gmatch '[^%.]+' do
    table.insert(parts, part)
  end

  -- Create nested structure
  local current = user_config
  for i = 1, #parts - 1 do
    local part = parts[i]
    if type(current[part]) ~= 'table' then
      current[part] = {}
    end
    current = current[part]
  end

  -- Set value at final level
  current[parts[#parts]] = value

  -- Update global variable
  vim.g.coc_user_config = user_config
  return true
end

function M.access(path, value)
  if value == nil then
    return M.get(path)
  else
    return M.set(path, value)
  end
end

return M
