local utils = require('grug-far/utils')

---@class AstgrepMatchPos
---@field line integer
---@field column integer

---@class AstgrepMatchOffset
---@field start integer
---@field end integer

---@class AstgrepMatchRange
---@field start AstgrepMatchPos
---@field end AstgrepMatchPos
---@field byteOffset AstgrepMatchOffset

---@class AstgrepMatch
---@field file string
---@field lines string
---@field replacement string
---@field range AstgrepMatchRange

--- parse results data and get info
---@param matches AstgrepMatch[]
---@return ParsedResultsData
local function parseResults(matches)
  -- return { lines = vim.split(data, '\n'), highlights = {}, stats = { files = 1, matches = 1 } }

  -- TODO (sbadragan): I think we have a problem cause you could get partial data
  -- for a file and then you are screwed...
  -- so we json decode before this function and wait until we get all the ones
  -- for a particular file or do the non-json route
  -- Then for the ones in a particular file, we can do replacements starting from the end

  local stats = { files = 0, matches = 0 }
  local lines = {}
  ---@type AstgrepMatchRange?
  local prevRange
  for i = #matches, 1, -1 do
    local match = matches[i]
    stats.matches = stats.matches + 1
    if i == #matches or match.file ~= matches[i + 1].file then
      stats.files = stats.files + 1
      prevRange = nil
    end

    local matchLines = vim.split(match.lines, '\n')
    if prevRange then
      -- remove overlapping lines
      local overlap = match.range['end'].line - prevRange.start.line
      for j = 0, overlap, 1 do
        local firstLine = table.remove(lines, 1)
        -- note: use overlapping lines from prev match, that have replacement performed
        -- as last lines of this match so that we get stacked replacements
        table.remove(matchLines, #matchLines - j)
        table.insert(matchLines, firstLine)
      end
    end

    -- perform replacements
    if match.replacement then
      local matchLinesStr = table.concat(matchLines, '\n')
      local matchStart = match.range.start.column
      local matchEnd = matchStart + (match.range.byteOffset['end'] - match.range.byteOffset.start)
      local replacedStr = matchLinesStr:sub(1, matchStart)
        .. match.replacement
        .. matchLinesStr:sub(matchEnd + 1, #matchLinesStr)
      matchLines = vim.split(replacedStr, '\n')
    end

    -- add new lines
    for k, matchLine in ipairs(matchLines) do
      table.insert(lines, k, matchLine)
    end

    prevRange = match.range
  end

  return {
    lines = vim.iter(lines):map(utils.getLineWithoutCarriageReturn):totable(),
    -- TODO (sbadragan): fixup
    highlights = {},
    stats = stats,
  }
end

return parseResults

-- Sample output:
-- console.log($A, $B, $C, $D, $E) on multi line
-- {
--   "text": "console.log(\n        'Error occurred when reading',\n        filePath,\n        filePath,\n        filePath,\n        filePath,\n      )",
--   "range": {
--     "byteOffset": {
--       "start": 1062,
--       "end": 1193
--     },
--     "start": {
--       "line": 24,
--       "column": 6
--     },
--     "end": {
--       "line": 30,
--       "column": 7
--     }
--   },
--   "file": "/opt/repos/frontend/scripts/update-tsconfig.mjs",
--   "lines": "      console.log(\n        'Error occurred when reading',\n        filePath,\n        filePath,\n        filePath,\n        filePath,\n      );",
--   "replacement": "boborepl.log('Error occurred when reading', filePath, filePath, filePath, filePath)",
--   "replacementOffsets": {
--     "start": 1062,
--     "end": 1193
--   },
--   "language": "JavaScript",
--   "metaVariables": {
--     "single": {
--       "E": {
--         "text": "filePath",
--         "range": {
--           "byteOffset": {
--             "start": 1176,
--             "end": 1184
--           },
--           "start": {
--             "line": 29,
--             "column": 8
--           },
--           "end": {
--             "line": 29,
--             "column": 16
--           }
--         }
--       },
--       "C": {
--         "text": "filePath",
--         "range": {
--           "byteOffset": {
--             "start": 1140,
--             "end": 1148
--           },
--           "start": {
--             "line": 27,
--             "column": 8
--           },
--           "end": {
--             "line": 27,
--             "column": 16
--           }
--         }
--       },
--       "A": {
--         "text": "'Error occurred when reading'",
--         "range": {
--           "byteOffset": {
--             "start": 1083,
--             "end": 1112
--           },
--           "start": {
--             "line": 25,
--             "column": 8
--           },
--           "end": {
--             "line": 25,
--             "column": 37
--           }
--         }
--       },
--       "D": {
--         "text": "filePath",
--         "range": {
--           "byteOffset": {
--             "start": 1158,
--             "end": 1166
--           },
--           "start": {
--             "line": 28,
--             "column": 8
--           },
--           "end": {
--             "line": 28,
--             "column": 16
--           }
--         }
--       },
--       "B": {
--         "text": "filePath",
--         "range": {
--           "byteOffset": {
--             "start": 1122,
--             "end": 1130
--           },
--           "start": {
--             "line": 26,
--             "column": 8
--           },
--           "end": {
--             "line": 26,
--             "column": 16
--           }
--         }
--       }
--     },
--     "multi": {},
--     "transformed": {}
--   }
-- }

-- multiple things on the same line:
-- const refs = nodes.map(node => ({
--   path: path.relative(refNode ? refNode.dir : rootDir, node.dir),
-- }));
-- search for:
-- $A.dir
-- bob
--
--
-- /opt/repos/frontend/scripts/update-tsconfig.mjs
-- {
--   "text": "refNode.dir",
--   "range": {
--     "byteOffset": {
--       "start": 1623,
--       "end": 1634
--     },
--     "start": {
--       "line": 50,
--       "column": 34
--     },
--     "end": {
--       "line": 50,
--       "column": 45
--     }
--   },
--   "file": "/opt/repos/frontend/scripts/update-tsconfig.mjs",
--   "lines": "    path: path.relative(refNode ? refNode.dir : rootDir, node.dir),",
--   "replacement": "bob",
--   "replacementOffsets": {
--     "start": 1623,
--     "end": 1634
--   },
--   "language": "JavaScript",
--   "metaVariables": {
--     "single": {
--       "A": {
--         "text": "refNode",
--         "range": {
--           "byteOffset": {
--             "start": 1623,
--             "end": 1630
--           },
--           "start": {
--             "line": 50,
--             "column": 34
--           },
--           "end": {
--             "line": 50,
--             "column": 41
--           }
--         }
--       }
--     },
--     "multi": {},
--     "transformed": {}
--   }
-- }
-- next one
-- {
--   "text": "node.dir",
--   "range": {
--     "byteOffset": {
--       "start": 1646,
--       "end": 1654
--     },
--     "start": {
--       "line": 50,
--       "column": 57
--     },
--     "end": {
--       "line": 50,
--       "column": 65
--     }
--   },
--   "file": "/opt/repos/frontend/scripts/update-tsconfig.mjs",
--   "lines": "    path: path.relative(refNode ? refNode.dir : rootDir, node.dir),",
--   "replacement": "bob",
--   "replacementOffsets": {
--     "start": 1646,
--     "end": 1654
--   },
--   "language": "JavaScript",
--   "metaVariables": {
--     "single": {
--       "A": {
--         "text": "node",
--         "range": {
--           "byteOffset": {
--             "start": 1646,
--             "end": 1650
--           },
--           "start": {
--             "line": 50,
--             "column": 57
--           },
--           "end": {
--             "line": 50,
--             "column": 61
--           }
--         }
--       }
--     },
--     "multi": {},
--     "transformed": {}
--   }
-- }
