local opts = require('grug-far/opts')

local function getStatusText(context)
  local s = context.state.status
  if s.status == 'error' then
    return opts.getIcon('resultsStatusError', context)
  elseif s.status == 'success' then
    return opts.getIcon('resultsStatusSuccess', context)
  elseif s.status == 'progress' then
    local progress_icons = opts.getIcon('resultsStatusProgressSeq', context)
    if progress_icons then
      return progress_icons[(s.count % #progress_icons) + 1]
    else
      return ''
    end
  end

  return opts.getIcon('resultsStatusReady', context)
end

local DEFAULT_SEPARATOR = '-----------------------------------------------------'
local function getSeparator(context)
  local separatorLine = opts.getIcon('resultsSeparatorLine', context) or DEFAULT_SEPARATOR
  return ' ' .. (getStatusText(context) or '') .. ' ' .. separatorLine
end

local function renderResultsHeader(buf, context)
  local headerRow = context.state.headerRow

  if not context.state.status then
    context.state.status = { status = nil }
  end

  context.extmarkIds.results_header = vim.api.nvim_buf_set_extmark(buf, context.namespace, headerRow, 0, {
    id = context.extmarkIds.results_header,
    end_row = headerRow,
    end_col = 0,
    virt_lines = {
      { { getSeparator(context), context.options.highlights.resultsHeader } },
    },
    virt_lines_leftcol = true,
    virt_lines_above = true,
    right_gravity = false
  })

  local stats = context.state.stats
  if stats then
    context.extmarkIds.results_stats = vim.api.nvim_buf_set_extmark(buf, context.namespace, headerRow, 0, {
      id = context.extmarkIds.results_stats,
      end_row = headerRow,
      end_col = 0,
      virt_lines = {
        { { ' ' .. stats.matches .. ' matches in ' .. stats.files .. ' files' .. ' ', context.options.highlights.resultsStats } },
      },
      virt_lines_leftcol = true,
      virt_lines_above = true,
      right_gravity = false
    })
  elseif context.extmarkIds.results_stats then
    vim.api.nvim_buf_del_extmark(buf, context.namespace, context.extmarkIds.results_stats)
    context.extmarkIds.results_stats = nil
  end
end

return renderResultsHeader
