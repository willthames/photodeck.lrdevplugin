-- local LrMobdebug = import 'LrMobdebug'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'

local logger = import 'LrLogger'( 'PhotoDeckPublishServiceProvider' )

logger:enable('print')

require 'PhotoDeckAPI'

local exportServiceProvider = {}

-- needed to publish in addition to export
exportServiceProvider.supportsIncrementalPublish = true
-- exportLocation gets replaced with PhotoDeck specific form section
exportServiceProvider.hideSections = { 'exportLocation' }

-- these fields get stored between uses
exportServiceProvider.exportPresetFields = {
  { key = 'username', default = "" },
  { key = 'fullname', default = "" },
  { key = 'apiKey', default = "" },
  { key = 'apiSecret', default = "" },
}

-- LrMobdebug.start()
local function  updateApiKeyAndSecret(propertyTable)
  local f = LrView.osFactory()
  local c = f:column {
    bind_to_object = propertyTable,
    spacing = f:dialog_spacing(),
    f:row {
      f:static_text {
        title = "API Key",
        width = LrView.share "label_width",
        alignment = "right",
      },
      f:edit_field {
        value = LrView.bind 'apiKey',
        immediate = false,
      }
    },
    f:row {
      f:static_text {
        title = "API Secret",
        width = LrView.share "label_width",
        alignment = "right",
      },
      f:edit_field {
        value = LrView.bind 'apiSecret',
        immediate = false,
      },
    },
  }
  result = LrDialogs.presentModalDialog({
    title = LOC "$$$/PhotoDeck/APIKeys=PhotoDeck API Keys",
    contents = c,
  })
  return propertyTable
end

function exportServiceProvider.startDialog(propertyTable)
  -- LrMobdebug.on()
  if apiKey == '' or apiSecret == '' then
    propertyTable = updateApiKeyAndSecret(propertyTable)
  end
end

function exportServiceProvider.sectionsForTopOfDialog( f, propertyTable )
  -- LrMobdebug.on()
  propertyTable.httpResult = 'Awaiting instructions'
  return {
    {
      title = LOC "$$$/PhotoDeck/ExportDialog/Account=PhotoDeck Account",
      synopsis = LrView.bind 'httpResult',

      f:row {
        bind_to_object = propertyTable,
        f:column {
          f:row {
            f:static_text {
              title = "API Key:",
              width = LrView.share "label_width",
              alignment = 'right'
            },
            f:static_text {
              title = LrView.bind 'apiKey',
              width_in_chars = 40,
            }
          },
          f:row {
            f:static_text {
              title = "API Secret:",
              width = LrView.share "label_width",
              alignment = 'right'
            },
            f:static_text {
              title = LrView.bind 'apiSecret',
              width_in_chars = 40,
            }
          },
        },
        f:column {
          f:push_button {
            title = 'Update',
            enabled = true,
            action = function()
              propertyTable = updateApiKeyAndSecret(propertyTable)
            end,
          }
        },
      },
      f:row {
        spacing = f:control_spacing(),

        f:static_text {
          title = LrView.bind 'httpResult',
          alignment = 'right',
          fill_horizontal = 1,
        },

        f:push_button {
          width = tonumber( LOC "$$$/locale_metric/PhotoDeck/ExportDialog/LoginButton/Width=90" ),
          title = 'Ping',
          enabled = true,
          action = function()
            propertyTable.httpResult = 'making api call'
            LrTasks.startAsyncTask(function()
              result, headers = PhotoDeckAPI.get('/ping.xml')
              propertyTable.httpResult = result
            end, 'PhotoDeckAPI Ping')
          end,
        },

      },
    },
  }
end

return exportServiceProvider
