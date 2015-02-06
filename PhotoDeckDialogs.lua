local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrProgressScope = import 'LrProgressScope'

local PhotoDeckAPI = require 'PhotoDeckAPI'
local PhotoDeckUtils = require 'PhotoDeckUtils'

local PhotoDeckDialogs = {}


-- Updates the website name in the plugin settings
local function updateWebsiteName(propertyTable, key, value)
  propertyTable.websiteName = propertyTable.websites[value].title
end


-- Ping PhotoDeck and show result in plugin settings
local function ping(propertyTable)
  propertyTable.connectionStatus = LOC "$$$/PhotoDeck/ConnectionStatus/Connecting=Connecting to PhotoDeck^."
  LrTasks.startAsyncTask(function()
    PhotoDeckAPI.connect(propertyTable.apiKey, propertyTable.apiSecret, propertyTable.username, propertyTable.password)
    local ping, error_msg = PhotoDeckAPI.ping()
    if error_msg then
      propertyTable.connectionStatus = LOC("$$$/PhotoDeck/ConnectionStatus/Failed=Connection failed: ^1", error_msg)
    elseif propertyTable.loggedin then
      propertyTable.connectionStatus = LOC "$$$/PhotoDeck/ConnectionStatus/Connected=Connected"
    else
      propertyTable.connectionStatus = LOC "$$$/PhotoDeck/ConnectionStatus/ConnectedPleaseLogin=Connected, please log in"
    end
  end, 'PhotoDeckAPI Ping')
end


-- Login in PhotoDeck and show result in plugin settings
local function login(propertyTable)
  propertyTable.connectionStatus = LOC "$$$/PhotoDeck/ConnectionStatus/LoggingIn=Logging in^."
  LrTasks.startAsyncTask(function()
    PhotoDeckAPI.connect(propertyTable.apiKey, propertyTable.apiSecret, propertyTable.username, propertyTable.password)
    local result, error_msg = PhotoDeckAPI.whoami()
    if error_msg then
      propertyTable.connectionStatus = error_msg
    elseif not PhotoDeckAPI.loggedin then
      propertyTable.connectionStatus = LOC "$$$/PhotoDeck/ConnectionStatus/CredentialsError=Couldn't log in using those credentials"
    else
      propertyTable.connectionStatus = LOC("$$$/PhotoDeck/ConnectionStatus/LoggedInAs=Logged in as ^1 ^2", result.firstname, result.lastname)
    end
    propertyTable.loggedin = PhotoDeckAPI.loggedin
    
    if PhotoDeckAPI.loggedin then
      -- get available websites
      websites, error_msg = PhotoDeckAPI.websites()
      if error_msg then
        propertyTable.connectionStatus = LOC("$$$/PhotoDeck/ConnectionStatus/FailedLoadingWebsite=Couldn't get your website: ^1", error_msg)
        propertyTable.loggedin = PhotoDeckAPI.loggedin
      else
        propertyTable.websites = websites
	propertyTable.websiteChoices = {}
	local websitesCount = 0
	local firstWebsite = nil
	local foundCurrent = false
        for k, v in pairs(propertyTable.websites) do
	  websitesCount = websitesCount + 1
          if not firstWebsite then
	    firstWebsite = k
          end
	  if k == propertyTable.websiteChosen then
	    foundCurrent = true
	  end
          table.insert(propertyTable.websiteChoices, { title = v.title .. " (" .. v.hostname .. ")", value = k })
        end
	if not foundCurrent then
          -- automatically select first website
	  propertyTable.websiteChosen = firstWebsite
	end
        propertyTable.multipleWebsites = websitesCount > 1
        updateWebsiteName(propertyTable, nil, propertyTable.websiteChosen)
      end

      -- show synchronization message if in progress
      if not propertyTable.canSynchronize then
        propertyTable.synchronizeGalleriesResult = LOC("$$$/PhotoDeck/SynchronizeStatus/InProgress=In progress")
      end
    end
  end, 'PhotoDeckAPI Login')
end


-- What happens when user clicks "Synchronize galleries" in plugin settings
local function synchronizeGalleries(propertyTable)
  propertyTable.synchronizeGalleriesResult = LOC("$$$/PhotoDeck/SynchronizeStatus/InProgress=In progress")
  propertyTable.canSynchronize = false
  local progressScope = LrProgressScope({
    title = LOC("$$$/PhotoDeck/SynchronizeStatus/Title=Gallery synchronization"),
    caption = LOC("$$$/PhotoDeck/SynchronizeStatus/Starting=Starting") })
  progressScope:setCancelable(true)
  LrTasks.startAsyncTask(function()
    PhotoDeckAPI.connect(propertyTable.apiKey, propertyTable.apiSecret, propertyTable.username, propertyTable.password)
    local result, error_msg = PhotoDeckAPI.synchronizeGalleries(propertyTable.websiteChosen, propertyTable.LR_publishService, progressScope)

    if error_msg then
      propertyTable.synchronizeGalleriesResult = error_msg
    elseif result then
      if result.created == 0 and result.deleted == 0 and result.updated == 0 and result.errors == 0 then
        propertyTable.synchronizeGalleriesResult = LOC("$$$/PhotoDeck/SynchronizeStatus/FinishedWithNoChanges=Finished, no changes")
      else
        propertyTable.synchronizeGalleriesResult = LOC("$$$/PhotoDeck/SynchronizeStatus/FinishedWithChanges=Finished: ^1 created, ^2 deleted, ^3 updated, ^4 errors", result.created, result.deleted, result.updated, result.errors)
      end
    else
      propertyTable.synchronizeGalleriesResult = "?"
    end
    propertyTable.canSynchronize = true
    progressScope:setCaption(propertyTable.synchronizeGalleriesResult)
    progressScope:done()
  end, 'PhotoDeckAPI galleries synchronization')
end


-- API key & secret dialog
function PhotoDeckDialogs.updateApiKeyAndSecret(propertyTable)
  local f = LrView.osFactory()
  local c = f:column {
    bind_to_object = propertyTable,
    spacing = f:dialog_spacing(),
    f:row {
      f:static_text {
        title = LOC "$$$/PhotoDeck/ApiKeyDialog/ApiKey=API Key:",
        width = LrView.share "label_width",
        alignment = "right",
      },
      f:edit_field {
        value = LrView.bind 'apiKey',
        immediate = false,
        width_in_chars = 40,
      }
    },
    f:row {
      f:static_text {
        title = LOC "$$$/PhotoDeck/ApiKeyDialog/ApiSecret=API Secret:",
        width = LrView.share "label_width",
        alignment = "right",
      },
      f:edit_field {
        value = LrView.bind 'apiSecret',
        immediate = false,
        width_in_chars = 40,
      },
    },
  }
  local result = LrDialogs.presentModalDialog({
    title = LOC "$$$/PhotoDeck/ApiKeyDialog/Title=PhotoDeck API Keys",
    contents = c,
  })
  return propertyTable
end


-- What happens when user clicks "Change website" in plugin settings
local function chooseWebsite(propertyTable)
  local f = LrView.osFactory()
  local c = f:row {
    spacing = f:dialog_spacing(),
    bind_to_object = propertyTable,
    f:popup_menu {
      items = LrView.bind 'websiteChoices',
      value = LrView.bind 'websiteChosen',
    },
  }
  local result = LrDialogs.presentModalDialog({
    title = LOC "$$$/PhotoDeck/WebsitesDialog/Title=PhotoDeck Websites",
    contents = c,
  })
  return propertyTable
end


-- Prevent the plugin settings dialog to be saved, until logged in
local function updateCantExportBecause(propertyTable)
  if not propertyTable.loggedin then
    propertyTable.LR_cantExportBecause = LOC "$$$/PhotoDeck/AccountDialog/NoLogin=You haven't logged in to PhotoDeck yet."
    return
  end
  propertyTable.LR_cantExportBecause = nil
end


-- Open plugin settings dialog
function PhotoDeckDialogs.startDialog(propertyTable)
  propertyTable.loggedin = false
  propertyTable.websiteChoices = {}
  propertyTable.galleryDisplayStyles = {}
  propertyTable.multipleWebsites = false
  propertyTable.websiteName = ''
  propertyTable.canSynchronize = PhotoDeckAPI.canSynchronize
  propertyTable.synchronizeGalleriesResult = ''

  if propertyTable.LR_editingExistingPublishConnection == false then
    -- new publish connection: reset credentials
    propertyTable.username = nil
    propertyTable.password = nil
    PhotoDeckAPI.loggedin = false
  end


  propertyTable:addObserver('loggedin', function() updateCantExportBecause(propertyTable) end)
  updateCantExportBecause(propertyTable)

  propertyTable:addObserver('websiteChosen', updateWebsiteName)

  local keysAreValid = PhotoDeckAPI.hasDistributionKeys or (
    propertyTable.apiKey and propertyTable.apiKey ~= '' and
    propertyTable.apiSecret and propertyTable.apiSecret ~= '')

  if not keysAreValid then
    propertyTable = PhotoDeckDialogs.updateApiKeyAndSecret(propertyTable)
  end
  if propertyTable.username and propertyTable.username ~= '' and
     propertyTable.password and propertyTable.password ~= '' and
     keysAreValid then
    login(propertyTable)
  else
    ping(propertyTable)
  end
end


-- Top plugin settings
function PhotoDeckDialogs.sectionsForTopOfDialog(f, propertyTable)
  local isPublish = not not propertyTable.LR_publishService

  local apiCredentials =  {
    title = LOC "$$$/PhotoDeck/ApiKeyDialog/Title=PhotoDeck API Keys",
    synopsis = LrView.bind 'connectionStatus',

    f:row {
      bind_to_object = propertyTable,
      f:column {
        f:row {
          f:static_text {
            title = LOC "$$$/PhotoDeck/ApiKeyDialog/ApiKey=API Key:",
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
            title = LOC "$$$/PhotoDeck/ApiKeyDialog/ApiSecret=API Secret:",
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
          title = LOC "$$$/PhotoDeck/ApiKeyDialog/ChangeAction=Change",
          action = function() propertyTable = PhotoDeckDialogs.updateApiKeyAndSecret(propertyTable) end,
        },
      },
    },
  }
  local userAccount = {
    title = LOC "$$$/PhotoDeck/AccountDialog/Title=PhotoDeck Account",
    synopsis = LrView.bind 'connectionStatus',

    f:row {
      bind_to_object = propertyTable,
      f:column {
        f:row {
          f:static_text {
            title = LOC "$$$/PhotoDeck/AccountDialog/Email=Email:",
            width = LrView.share "user_label_width",
            alignment = 'right'
          },
          f:edit_field {
            value = LrView.bind 'username',
            width = 300,
          }
        },
        f:row {
          f:static_text {
            title = LOC "$$$/PhotoDeck/AccountDialog/Password=Password:",
            width = LrView.share "user_label_width",
            alignment = 'right'
          },
          f:password_field {
            value = LrView.bind 'password',
            width = 300,
          }
        },
      },

      f:column {
        f:push_button {
          title = LOC "$$$/PhotoDeck/AccountDialog/LoginAction=Login",
          enabled = LrBinding.negativeOfKey('loggedin'),
          action = function () login(propertyTable) end
        },
      },
    },

    f:row {
      bind_to_object = propertyTable,
      f:column {
        f:static_text {
          title = "",
          width = LrView.share "user_label_width",
          alignment = 'right'
        },
      },
      f:column {
        f:static_text {
          title = LrView.bind 'connectionStatus',
	  font = '<system/small/bold>',
	  width = 300,
	  height_in_lines = 2
        },
      },
    },

    f:row {
      bind_to_object = propertyTable,
      f:column {
	f:row {
          f:static_text {
	    visible = LrBinding.andAllKeys('loggedin'),
            title = LOC "$$$/PhotoDeck/AccountDialog/Website=Website:",
            width = LrView.share "user_label_width",
            alignment = 'right'
          },
          f:static_text {
	    visible = LrBinding.andAllKeys('loggedin'),
            title = LrView.bind 'websiteName',
            width = 300,
          }
        },
      },

      f:column {
        f:push_button {
          title = LOC "$$$/PhotoDeck/AccountDialog/WebsiteChangeAction=Change",
	  visible = LrBinding.andAllKeys('loggedin'),
	  enabled = LrBinding.andAllKeys('loggedin', 'multipleWebsites'),
          action = function() propertyTable = chooseWebsite(propertyTable) end,
        },
      },
    }
  }
  local publishSettings = {
    title = LOC "$$$/PhotoDeck/PublishOptionsDialog/Title=PhotoDeck Publish options",

    f:row {
      bind_to_object = propertyTable,

      f:checkbox {
        title = LOC "$$$/PhotoDeck/PublishOptionsDialog/UploadOnRepublish=Re-upload photo when re-publishing",
        value = LrView.bind 'uploadOnRepublish'
      }
    },

    f:row {
      f:push_button {
        title = LOC "$$$/PhotoDeck/PublishOptionsDialog/SynchronizeGalleries/Action=Import PhotoDeck galleries",
        action = function()
		   local result = LrDialogs.confirm(
		     LOC "$$$/PhotoDeck/PublishOptionsDialog/SynchronizeGalleries/ConfirmTitle=This will mirror your existing PhotoDeck galleries in Lightroom.",
		     LOC "$$$/PhotoDeck/PublishOptionsDialog/SynchronizeGalleries/ConfirmSubtitle=Gallery content is currently not imported.",
		     LOC "$$$/PhotoDeck/PublishOptionsDialog/SynchronizeGalleries/ProceedAction=Proceed",
		     LOC "$$$/PhotoDeck/PublishOptionsDialog/SynchronizeGalleries/CancelAction=Cancel")
		   if result == "ok" then
                     synchronizeGalleries(propertyTable)
	           end
	end,
	enabled = LrBinding.andAllKeys('loggedin', 'canSynchronize'),
      },

      f:static_text {
        title = LrView.bind 'synchronizeGalleriesResult',
        alignment = 'right',
        fill_horizontal = 1,
        height_in_lines = 1,
      },
    }
  }

  local dialogs = {}
  if not PhotoDeckAPI.hasDistributionKeys then
    table.insert(dialogs, apiCredentials)
  end
  table.insert(dialogs, userAccount);
  if isPublish then
    table.insert(dialogs, publishSettings);
  end
  return dialogs
end


-- Dialog when a publish service has been created
function PhotoDeckDialogs.didCreateNewPublishService(publishSettings, info)
  local result = LrDialogs.confirm(
    LOC "$$$/PhotoDeck/InitialSynchronizationDialog/Title=Would you like to import your existing PhotoDeck galleries in Lightroom now?",
    LOC "$$$/PhotoDeck/InitialSynchronizationDialog/ConfirmSubtitle=Gallery content is currently not imported.^n^nYou can also import (or re-import) your PhotoDeck galleries later from the publish service settings.",
    LOC "$$$/PhotoDeck/InitialSynchronizationDialog/ProceedAction=Yes, proceed now",
    LOC "$$$/PhotoDeck/InitialSynchronizationDialog/NoAction=No")
  if result == "ok" then
    publishSettings.LR_publishService = info.publishService
    synchronizeGalleries(publishSettings)
  end
end


-- What happens when a gallery display style is selected
local function onGalleryDisplayStyleSelect(propertyTable, key, value)
  local chosenStyle = PhotoDeckUtils.filter(propertyTable.galleryDisplayStyles, function(v) return v.value == value end)
  if #chosenStyle > 0 then
    propertyTable.galleryDisplayStyleName = chosenStyle[1].title
  end
end


-- What happens when user clicks "Change gallery display style"
local function chooseGalleryDisplayStyle(propertyTable, collectionInfo)
  local f = LrView.osFactory()
  local c = f:row {
    spacing = f:dialog_spacing(),
    bind_to_object = collectionInfo,
    f:popup_menu {
      items = LrView.bind 'galleryDisplayStyles',
      value = LrView.bind { bind_to_object = collectionInfo, key = 'display_style' }
    },
  }
  local result = LrDialogs.presentModalDialog({
    title = LOC "$$$/PhotoDeck/GalleryDisplayStylesDialog/Title=Gallery Display Styles",
    contents = c,
  })
  return propertyTable
end


-- Published Collection (=gallery) & Published Collection Set (=folder) settings
PhotoDeckDialogs.viewForCollectionSettings = function(f, publishSettings, info)
  info.collectionSettings:addObserver('display_style', onGalleryDisplayStyleSelect)

  info.collectionSettings.galleryDisplayStyles = {}

  publishSettings.connectionStatus = LOC "$$$/PhotoDeck/CollectionSettingsDialog/ConnectionStatus/Connecting=Connecting to PhotoDeck^."
  LrTasks.startAsyncTask(function()
    PhotoDeckAPI.connect(publishSettings.apiKey, publishSettings.apiSecret, publishSettings.username, publishSettings.password)
    local error_msg = nil

    local publishedCollection = info.publishedCollection
    if publishedCollection then
      local galleryId = publishedCollection:getRemoteId()
      if galleryId and galleryID ~= '' then
        -- read current live settings
        local gallery
        gallery, error_msg = PhotoDeckAPI.gallery(publishSettings.websiteChosen, galleryId)
        if error_msg then
          publishSettings.connectionStatus = LOC("$$$/PhotoDeck/CollectionSettingsDialog/ConnectionStatus/GalleryFailed=Error reading gallery from PhotoDeck: ^1", error_msg)
        else
	  info.collectionSettings.LR_liveName = gallery.name
  	  info.collectionSettings.description = gallery.description
	  info.collectionSettings.display_style = gallery.displaystyle
        end
      end
    end

    if not error_msg then
      local galleryDisplayStyles
      galleryDisplayStyles, error_msg = PhotoDeckAPI.galleryDisplayStyles(publishSettings.websiteChosen)
      if error_msg then
        publishSettings.connectionStatus = LOC("$$$/PhotoDeck/CollectionSettingsDialog/ConnectionStatus/GalleryDisplayStylesFailed=Error reading gallery display styles from PhotoDeck: ^1", error_msg)
      elseif galleryDisplayStyles then
        -- populate gallery display style choices
        for k, v in pairs(galleryDisplayStyles) do
          table.insert(info.collectionSettings.galleryDisplayStyles, { title = v.name, value = v.uuid })
        end
        if info.collectionSettings.display_style and info.collectionSettings.display_style ~= '' then
          onGalleryDisplayStyleSelect(info.collectionSettings, nil, info.collectionSettings.display_style)
        end
      end
    end

    if not error_msg then
      publishSettings.connectionStatus = LOC("$$$/PhotoDeck/CollectionSettingsDialog/ConnectionStatus/OK=Connected to PhotoDeck")
    end

  end, 'PhotoDeckAPI Get Gallery Attributes')

  local c = f:view {
    bind_to_object = info,
    spacing = f:dialog_spacing(),

    f:row {
      f:static_text {
        bind_to_object = publishSettings,
        title = LrView.bind 'connectionStatus',
	font = '<system/small/bold>',
	fill_horizontal = 1
      }
    },
    f:row {
      f:static_text {
        title = LOC("$$$/PhotoDeck/CollectionSettingsDialog/Description=Introduction:"),
        width = LrView.share "collectionset_labelwidth",
      },
      f:edit_field {
        bind_to_object = info.collectionSettings,
        value = LrView.bind 'description',
        width_in_chars = 60,
        height_in_lines = 8,
      }
    },
    f:row {
      f:static_text {
        title = LOC("$$$/PhotoDeck/CollectionSettingsDialog/GalleryDisplayStyle=Gallery Style:"),
        width = LrView.share "collectionset_labelwidth",
      },
      f:static_text {
        bind_to_object = info.collectionSettings,
        title = LrView.bind 'galleryDisplayStyleName',
        width_in_chars = 30,
	fill_horizontal = 1
      },
      f:push_button {
        bind_to_object = info.collectionSettings,
        action = function() chooseGalleryDisplayStyle(publishSettings, info.collectionSettings) end,
        enabled = LrBinding.keyIsNotNil 'galleryDisplayStyles',
        title = LOC("$$$/PhotoDeck/CollectionSettingsDialog/ChooseGalleryDisplayStyleAction=Change Style"),
      }
    },
  }
  return c
end


-- Done
return PhotoDeckDialogs
