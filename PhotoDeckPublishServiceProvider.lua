-- local LrMobdebug = import 'LrMobdebug'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'

local logger = import 'LrLogger'( 'PhotoDeckPublishServiceProvider' )

logger:enable('print')

local PhotoDeckAPI = require 'PhotoDeckAPI'

local exportServiceProvider = {}

-- needed to publish in addition to export
exportServiceProvider.supportsIncrementalPublish = true
-- exportLocation gets replaced with PhotoDeck specific form section
exportServiceProvider.hideSections = { 'exportLocation' }
exportServiceProvider.small_icon = 'photodeck16.png'

-- these fields get stored between uses
exportServiceProvider.exportPresetFields = {
  { key = 'username', default = "" },
  { key = 'password', default = "" },
  { key = 'fullname', default = "" },
  { key = 'apiKey', default = "" },
  { key = 'apiSecret', default = "" },
  { key = 'website', default = "" },
}

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

local function login(propertyTable)
  propertyTable.loggedinResult = 'logging in...'
  PhotoDeckAPI.connect(propertyTable.apiKey, 
       propertyTable.apiSecret, propertyTable.username, propertyTable.password)
  LrTasks.startAsyncTask(function()
    local result = PhotoDeckAPI.whoami()
    propertyTable.loggedin = true
    propertyTable.loggedinResult = 'Logged in as ' .. result.firstname .. ' ' .. result.lastname
  end, 'PhotoDeckAPI Login')
end

local function getWebsites(propertyTable)
  PhotoDeckAPI.connect(propertyTable.apiKey, 
       propertyTable.apiSecret, propertyTable.username, propertyTable.password)
  LrTasks.startAsyncTask(function()
    propertyTable.websiteChoices = PhotoDeckAPI.websites()
  end, 'PhotoDeckAPI Get Websites')
end

function exportServiceProvider.startDialog(propertyTable)
  propertyTable.loggedin = false
  if propertyTable.apiKey == '' or propertyTable.apiSecret == '' then
    propertyTable = updateApiKeyAndSecret(propertyTable)
  end
  if #propertyTable.username and #propertyTable.password and
    #propertyTable.apiKey and #propertyTable.apiSecret then
    login(propertyTable)
    -- getWebsites(propertyTable)
  end
end

function exportServiceProvider.sectionsForTopOfDialog( f, propertyTable )
  -- LrMobdebug.on()
  propertyTable.httpResult = 'Awaiting instructions'
  propertyTable.loggedinResult = 'Not logged in'

  local apiCredentials =  {
    title = LOC "$$$/PhotoDeck/ExportDialog/Account=PhotoDeck Plugin API keys",
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
        height_in_lines = 5,
      },

      f:push_button {
        width = tonumber( LOC "$$$/locale_metric/PhotoDeck/ExportDialog/LoginButton/Width=90" ),
        title = 'Ping',
        enabled = true,
        action = function()
          propertyTable.httpResult = 'making api call'
          PhotoDeckAPI.connect(propertyTable.apiKey, propertyTable.apiSecret)
          LrTasks.startAsyncTask(function()
            result, headers = PhotoDeckAPI.get('/ping.xml')
            propertyTable.httpResult = result
          end, 'PhotoDeckAPI Ping')
        end,
      },

    },
  }
  local userCredentials = {
    title = LOC "$$$/PhotoDeck/ExportDialog/Account=PhotoDeck Account",
    synopsis = LrView.bind 'loggedinResult',

    f:row {
      bind_to_object = propertyTable,
      f:column {
        f:row {
          f:static_text {
            title = "Username:",
            width = LrView.share "user_label_width",
            alignment = 'right'
          },
          f:edit_field {
            value = LrView.bind 'username',
            width_in_chars = 20,
          }
        },
        f:row {
          f:static_text {
            title = "Password:",
            width = LrView.share "user_label_width",
            alignment = 'right'
          },
          f:password_field {
            value = LrView.bind 'password',
            width_in_chars = 20,
          }
        },
      },

      f:push_button {
        width = tonumber( LOC "$$$/locale_metric/PhotoDeck/ExportDialog/TestButton/Width=90" ),
        title = 'Login',
        enabled = LrView.bind 'loggedin',
        action = function () login(propertyTable) end
      },

      f:static_text {
        title = LrView.bind 'loggedinResult',
        alignment = 'right',
        fill_horizontal = 1,
        height_in_lines = 1,
      },

    },
  }
  local websiteChoice = {
    title = LOC "$$$/PhotoDeck/ExportDialog/Account=PhotoDeck Website",
    synopsis = LrView.bind 'websiteChosen',

    f:row {
      bind_to_object = propertyTable,

      f:push_button {
        enabled = true,
        title = 'Get websites',
        action = function () getWebsites(propertyTable) end
      },

      f:popup_menu {
        items = LrView.bind 'websiteChoices',
        value = LrView.bind 'websiteChosen',
      }

    }
  }

  return {
    apiCredentials,
    userCredentials,
    websiteChoice,
  }
end

return exportServiceProvider
