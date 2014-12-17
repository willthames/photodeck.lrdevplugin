-- local LrMobdebug = import 'LrMobdebug'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

local logger = import 'LrLogger'( 'PhotoDeckPublishServiceProvider' )

logger:enable('print')

local PhotoDeckAPI = require 'PhotoDeckAPI'
local PhotoDeckUtils = require 'PhotoDeckUtils'
local printTable = PhotoDeckUtils.printTable

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
  { key = 'websiteChosen', default = "" },
  { key = 'websites', default = {} },
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
  local result = LrDialogs.presentModalDialog({
    title = LOC "$$$/PhotoDeck/APIKeys=PhotoDeck API Keys",
    contents = c,
  })
  return propertyTable
end

local function ping(propertyTable)
  propertyTable.pingResult = 'making api call'
  PhotoDeckAPI.connect(propertyTable.apiKey, propertyTable.apiSecret)
  LrTasks.startAsyncTask(function()
    propertyTable.pingResult = PhotoDeckAPI.ping()
  end, 'PhotoDeckAPI Ping')
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
    propertyTable.websites = PhotoDeckAPI.websites()
    propertyTable.websiteChoices = {}
    for k, v in pairs(propertyTable.websites) do
      table.insert(propertyTable.websiteChoices, { title = v.title, value = k })
    end
    logger:trace(printTable(propertyTable.websiteChoices))
    logger:trace(printTable(propertyTable.websites))
  end, 'PhotoDeckAPI Get Websites')
end

function exportServiceProvider.startDialog(propertyTable)
  propertyTable.loggedin = false
  if propertyTable.apiKey == '' or propertyTable.apiSecret == '' then
    propertyTable = updateApiKeyAndSecret(propertyTable)
  end
  ping(propertyTable)
  if #propertyTable.username and #propertyTable.password and
    #propertyTable.apiKey and #propertyTable.apiSecret then
    login(propertyTable)
    getWebsites(propertyTable)
  end
end

function exportServiceProvider.sectionsForTopOfDialog( f, propertyTable )
  -- LrMobdebug.on()
  propertyTable.pingResult = 'Awaiting instructions'
  propertyTable.loggedinResult = 'Not logged in'

  local apiCredentials =  {
    title = LOC "$$$/PhotoDeck/ExportDialog/Account=PhotoDeck Plugin API keys",
    synopsis = LrView.bind 'pingResult',

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
        },
        f:static_text {
          title = LrView.bind 'pingResult',
          alignment = 'right',
          fill_horizontal = 1,
        },
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
        enabled = LrBinding.negativeOfKey('loggedin'),
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

      f:static_text {
        title = 'Choose website',
      },

      f:popup_menu {
        title = "Select Website",
        items = LrView.bind 'websiteChoices',
        value = LrView.bind 'websiteChosen',
      },

    }
  }

  return {
    apiCredentials,
    userCredentials,
    websiteChoice,
  }
end


function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )

  local exportSession = exportContext.exportSession
  local exportSettings = assert( exportContext.propertyTable )
  local nPhotos = exportSession:countRenditions()
  PhotoDeckAPI.connect(exportSettings.apiKey,
       exportSettings.apiSecret, exportSettings.username, exportSettings.password)

  -- Set progress title.
  local progressScope = exportContext:configureProgress {
    title = nPhotos > 1
    and LOC( "$$$/PhotoDeck/Publish/Progress=Publishing ^1 photos to PhotoDeck", nPhotos )
    or LOC "$$$/PhotoDeck/Publish/Progress/One=Publishing one photo to PhotoDeck",
  }

  -- Save off uploaded photo IDs so we can take user to those photos later.
  local uploadedPhotoIds = {}
  local publishedCollectionInfo = exportContext.publishedCollectionInfo
  -- Look for a gallery id for this collection.
  local galleryId = publishedCollectionInfo.remoteId
  local galleryPhotos
  local gallery
  local urlname = exportSettings.websiteChosen

  if not galleryId then
    -- Create or update this gallery.
    gallery = PhotoDeckAPI.createOrUpdateGallery(exportSettings, publishedCollectionInfo)
  else
    -- Get a list of photos already in this gallery so we know which ones we can replace and which have
    -- to be re-uploaded entirely.
    local galleries = PhotoDeckAPI.galleries(urlname)
    gallery = galleries[galleryId]
    galleryPhotos = PhotoDeckAPI.photosInGallery(exportSettings, gallery)
  end
  exportSession:recordRemoteCollectionId(gallery.uuid)
  local website = PhotoDeckAPI.websites()[urlname]
  gallery.fullurl = website.homeurl .. "/-/" .. gallery.urlpath
  exportSession:recordRemoteCollectionUrl(gallery.fullurl)

  local photodeckPhotoIdsForRenditions = {}

  -- Gather photodeck photo IDs, and if we're on a free account, remember the renditions that
  -- had been previously published.

  for i, rendition in exportContext.exportSession:renditions() do
    local photodeckPhotoId = rendition.publishedPhotoId
    if photodeckPhotoId then
      -- Check to see if the photo is still on PhotoDeck.
      if not galleryPhotos[ photodeckPhotoId ] then
        photodeckPhotoId = nil
      end
    end

    photodeckPhotoIdsForRenditions[ rendition ] = photodeckPhotoId
  end

  -- Iterate through photo renditions.
  for i, rendition in exportContext:renditions { stopIfCanceled = true } do
    -- Update progress scope.
    progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
    -- Get next photo.
    local photo = rendition.photo

    -- See if we previously uploaded this photo.
    local photodeckPhotoId = photodeckPhotoIdsForRenditions[ rendition ]

    if not rendition.wasSkipped then
      local success, pathOrMessage = rendition:waitForRender()
      -- Update progress scope again once we've got rendered photo.
      progressScope:setPortionComplete( ( i - 0.5 ) / nPhotos )
      -- Check for cancellation again after photo has been rendered.
      if progressScope:isCanceled() then break end
      if success then
        -- Build up common metadata for this photo.
        local description = photo:getFormattedMetadata( 'caption' )
        local keywordTags = photo:getFormattedMetadata( 'keywordTagsForExport' )
        local tags = {}

        if keywordTags then
          local keywordIter = string.gfind( keywordTags, "[^,]+" )
          for keyword in keywordIter do
            if string.sub( keyword, 1, 1 ) == ' ' then
              keyword = string.sub( keyword, 2, -1 )
            end

            if string.find( keyword, ' ' ) ~= nil then
              keyword = '"' .. keyword .. '"'
            end

            tags[ #tags + 1 ] = keyword
          end
        end

        -- Upload or replace the photo.
        local upload
        if not photodeckPhotoId then
          upload = PhotoDeckAPI.uploadPhoto( exportSettings, {
            filePath = pathOrMessage,
            gallery = gallery.uuid,
          } )
        else
          upload = PhotoDeckAPI.getPhoto(exportSettings, photodeckPhotoId)
        end

        -- Use the below code once we know what we want to update
        --[[
        PhotoDeckAPI.updatePhoto(exportSettings, upload, {
          description = description,
          tags = table.concat( tags, ',' ),
        })
        --]]

        -- When done with photo, delete temp file. There is a cleanup step that happens later,
        -- but this will help manage space in the event of a large upload.
        LrFileUtils.delete( pathOrMessage )

        -- Remember this in the list of photos we uploaded.
        uploadedPhotoIds[ #uploadedPhotoIds + 1 ] = upload.uuid

        -- Record this PhotoDeck ID with the photo so we know to replace instead of upload.
        rendition:recordPublishedPhotoId( upload.uuid )
        -- Add the uploaded photos to the correct gallery.
        rendition:recordPublishedPhotoUrl( upload.url )
      end
    end
  end

  progressScope:done()

end

return exportServiceProvider
