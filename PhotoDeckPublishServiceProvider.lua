local LrApplication = import 'LrApplication'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrErrors = import 'LrErrors'

local logger = import 'LrLogger'( 'PhotoDeckPublishLightroomPlugin' )

logger:enable('logfile')

local PhotoDeckAPI = require 'PhotoDeckAPI'
local PhotoDeckUtils = require 'PhotoDeckUtils'
local printTable = PhotoDeckUtils.printTable
local filter = PhotoDeckUtils.filter
local map = PhotoDeckUtils.map

local publishServiceProvider = {}

-- needed to publish in addition to export
publishServiceProvider.supportsIncrementalPublish = true
-- exportLocation gets replaced with PhotoDeck specific form section
publishServiceProvider.hideSections = { 'exportLocation' }
publishServiceProvider.small_icon = 'photodeck16.png'

publishServiceProvider.titleForPublishedCollection = "Gallery"
publishServiceProvider.titleForPublishedCollectionSet = "Folder"
publishServiceProvider.titleForGoToPublishedCollection = "Go to Gallery"
publishServiceProvider.disableRenamePublishedCollectionSet = true

-- these fields get stored between uses
publishServiceProvider.exportPresetFields = {
  { key = 'username', default = "" },
  { key = 'password', default = "" },
  { key = 'fullname', default = "" },
  { key = 'apiKey', default = "" },
  { key = 'apiSecret', default = "" },
  { key = 'websiteChosen', default = "" },
  { key = 'uploadOnRepublish', default = false },
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
        width_in_chars = 40,
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
        width_in_chars = 40,
      },
    },
  }
  local result = LrDialogs.presentModalDialog({
    title = LOC "$$$/PhotoDeck/APIKeys=PhotoDeck API Keys",
    contents = c,
  })
  return propertyTable
end

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
    title = LOC "$$$/PhotoDeck/WebsiteChoice=PhotoDeck Websites",
    contents = c,
  })
  return propertyTable
end

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
    title = LOC "$$$/PhotoDeck/GalleryDisplayStyle=Gallery Display Style",
    contents = c,
  })
  return propertyTable
end

local function ping(propertyTable)
  propertyTable.pingResult = 'Connecting to PhotoDeck...'
  PhotoDeckAPI.connect(propertyTable.apiKey, propertyTable.apiSecret)
  LrTasks.startAsyncTask(function()
    propertyTable.pingResult = PhotoDeckAPI.ping()
  end, 'PhotoDeckAPI Ping')
end

local function login(propertyTable)
  propertyTable.loggedinResult = 'Logging in...'
  PhotoDeckAPI.connect(propertyTable.apiKey,
       propertyTable.apiSecret, propertyTable.username, propertyTable.password)
  LrTasks.startAsyncTask(function()
    local result, error_msg = PhotoDeckAPI.whoami()
    if error_msg then
      propertyTable.loggedin = false
      propertyTable.loggedinResult = error_msg
    elseif not result.email or result.email == '' then
      propertyTable.loggedin = false
      propertyTable.loggedinResult = "Couldn't log in using those credentials"
    else
      propertyTable.loggedin = true
      propertyTable.loggedinResult = 'Logged in as ' .. result.firstname .. ' ' .. result.lastname
    end
  end, 'PhotoDeckAPI Login')
end

local function onGalleryDisplayStyleSelect(propertyTable, key, value)
  local chosenStyle = filter(propertyTable.galleryDisplayStyles, function(v) return v.value == value end)
  if #chosenStyle > 0 then
    propertyTable.galleryDisplayStyleName = chosenStyle[1].title
  end
end

local function getGalleryDisplayStyles(propertyTable, collectionInfo)
  collectionInfo.galleryDisplayStyles = {}
  PhotoDeckAPI.connect(propertyTable.apiKey,
       propertyTable.apiSecret, propertyTable.username, propertyTable.password)
  LrTasks.startAsyncTask(function()
    local galleryDisplayStyles, error_msg = PhotoDeckAPI.galleryDisplayStyles(propertyTable.websiteChosen)
    if galleryDisplayStyles and not error_msg then
      for k, v in pairs(galleryDisplayStyles) do
        table.insert(collectionInfo.galleryDisplayStyles, { title = v.name, value = v.uuid })
      end
      if collectionInfo.display_style and collectionInfo.display_style ~= '' then
        onGalleryDisplayStyleSelect(collectionInfo, nil, collectionInfo.display_style)
      end
    end
  end, 'PhotoDeckAPI Get Gallery Display Styles')
end

local function onWebsiteSelect(propertyTable, key, value)
  propertyTable.websiteName = propertyTable.websites[value].title
end

local function getWebsites(propertyTable)
  PhotoDeckAPI.connect(propertyTable.apiKey,
       propertyTable.apiSecret, propertyTable.username, propertyTable.password)
  LrTasks.startAsyncTask(function()
    websites, error_msg = PhotoDeckAPI.websites()
    if not error_msg then
      propertyTable.websites = websites
      for k, v in pairs(propertyTable.websites) do
        table.insert(propertyTable.websiteChoices, { title = v.title, value = k })
      end
      if propertyTable.websiteChosen and propertyTable.websiteChosen ~= '' then
        onWebsiteSelect(propertyTable, nil, propertyTable.websiteChosen)
      end
    end
  end, 'PhotoDeckAPI Get Websites')
end

function publishServiceProvider.startDialog(propertyTable)
  propertyTable.loggedin = false
  propertyTable.websiteChoices = {}
  propertyTable.galleryDisplayStyles = {}
  propertyTable.websiteName = ''
  if not propertyTable.apiKey or propertyTable.apiKey == ''
    or not propertyTable.apiSecret or propertyTable.apiSecret == '' then
    propertyTable = updateApiKeyAndSecret(propertyTable)
  end
  ping(propertyTable)
  if propertyTable.username and propertyTable.username ~= '' and
     propertyTable.password and propertyTable.password ~= '' and
     propertyTable.apiKey and propertyTable.apiKey ~= '' and
     propertyTable.apiSecret and propertyTable.apiSecret ~= '' then
    login(propertyTable)
    getWebsites(propertyTable)
  end

  propertyTable:addObserver('websiteChosen', onWebsiteSelect)
end

function publishServiceProvider.sectionsForTopOfDialog( f, propertyTable )
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
        action = function ()
          login(propertyTable)
          getWebsites(propertyTable)
        end
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
    synopsis = LrView.bind 'websiteName',

    f:row {
      bind_to_object = propertyTable,

      f:push_button {
        title = 'Choose website',
        action = function() propertyTable = chooseWebsite(propertyTable) end,
        enabled = LrView.bind 'loggedin'
      },
      f:static_text {
        title = LrView.bind 'websiteName',
        width_in_chars = 40,
      }
    }
  }
  local publishSettings = {
    title = LOC "$$$/PhotoDeck/ExportDialog/Account=PhotoDeck publish settings",
    synopsis = LrView.bind 'websiteName',

    f:row {
      bind_to_object = propertyTable,

      f:checkbox {
        title = 'Re-upload photo when re-publishing',
        value = LrView.bind 'uploadOnRepublish'
      }
    }
  }

  return {
    apiCredentials,
    userCredentials,
    websiteChoice,
    publishSettings
  }
end

function publishServiceProvider.processRenderedPhotos( functionContext, exportContext )

  local exportSession = exportContext.exportSession
  local exportSettings = assert( exportContext.propertyTable )
  local nPhotos = exportSession:countRenditions()
  PhotoDeckAPI.connect(exportSettings.apiKey,
       exportSettings.apiSecret, exportSettings.username, exportSettings.password)

  local error_msg

  -- Set progress title.
  local progressScope = exportContext:configureProgress {
    title = nPhotos > 1
    and LOC( "$$$/PhotoDeck/Publish/Progress=Publishing ^1 photos to PhotoDeck", nPhotos )
    or LOC "$$$/PhotoDeck/Publish/Progress/One=Publishing one photo to PhotoDeck",
  }

  -- Save off uploaded photo IDs so we can take user to those photos later.
  local uploadedPhotoIds = {}
  local collectionInfo = exportContext.publishedCollectionInfo
  -- Look for a gallery id for this collection.
  local galleryId = collectionInfo.remoteId
  local galleryPhotos
  local urlname = exportSettings.websiteChosen
  local gallery = nil

  if galleryId then
    gallery, error_msg = PhotoDeckAPI.gallery(urlname, galleryId)
    if error_msg then
      progressScope:done()
      LrErrors.throwUserError("Error retrieving gallery: " .. error_msg)
      return
    end
  end

  if not gallery then
    -- Create or update this gallery.
    if not collectionInfo.publishedCollection then
      collectionInfo.publishedCollection = exportContext.publishedCollection
    end
    gallery, error_msg = PhotoDeckAPI.createOrUpdateGallery(urlname, collectionInfo.name, collectionInfo)
    if error_msg then
      progressScope:done()
      LrErrors.throwUserError("Error creating gallery: " .. error_msg)
      return
    end
  end

  -- gather information for dealing with recordPublishedPhotoUrl bug
  local catalog = exportSession.catalog
  local collection = exportContext.publishedCollection
  local publishedPhotos = collection:getPublishedPhotos()
  local publishedPhotoById = {}
  for _, pp in pairs(publishedPhotos) do
    publishedPhotoById[pp:getPhoto().localIdentifier] = pp
  end

  -- Iterate through photo renditions.
  for i, rendition in exportContext:renditions { stopIfCanceled = true } do
    -- Update progress scope.
    progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
    -- Get next photo.
    local photo = rendition.photo

    -- See if we previously uploaded this photo.
    local photoId = rendition.publishedPhotoId or uploadedPhotoIds[photo.localIdentifier]
    if not photoId then
      -- previously uploaded in another gallery?
      catalog:withReadAccessDo( function()
        photoId = photo:getPropertyForPlugin(_PLUGIN, "photoId")
      end)
    end

    if not rendition.wasSkipped then
      local success, pathOrMessage = rendition:waitForRender()
      -- Update progress scope again once we've got rendered photo.
      progressScope:setPortionComplete( ( i - 0.5 ) / nPhotos )
      -- Check for cancellation again after photo has been rendered.
      if progressScope:isCanceled() then break end
      if success then
        error_msg = nil

        local photoAlreadyPublished = not not photoId
	if photoAlreadyPublished then
	  local remotePhoto
	  remotePhoto, error_msg = PhotoDeckAPI.getPhoto(photoId)
	  photoAlreadyPublished = not not remotePhoto
        end

	local upload
	if not error_msg then
          -- Build list of photo attributes
          local photoAttributes = {}
          local publishedPhoto = publishedPhotoById[photo.localIdentifier]
          local needsUpload = not photoAlreadyPublished or exportSettings.uploadOnRepublish
  
          if needsUpload then
            photoAttributes.contentPath = pathOrMessage
          end
          photoAttributes.publishToGallery = gallery
          photoAttributes.lrPhoto = photo
  
          -- Upload or replace/update the photo.
          if photoAlreadyPublished then
            upload, error_msg = PhotoDeckAPI.updatePhoto(photoId, urlname, photoAttributes)
          else
            upload, error_msg = PhotoDeckAPI.uploadPhoto(urlname, photoAttributes)
          end
        end

	if not error_msg and upload and upload.uuid and upload.uuid ~= "" then
          --logger:trace(printTable(upload))

          rendition:recordPublishedPhotoId(upload.uuid)
	  if upload.url then
            rendition:recordPublishedPhotoUrl(upload.url)
          end

	  -- Remember this in the list of photos we uploaded.
	  uploadedPhotoIds[photo.localIdentifier] = upload.uuid


	  -- Also save the remote photo ID at the LrPhoto level, so that we can find it when publishing in a different gallery
	  catalog:withWriteAccessDo( "publish", function( context )
            photo:setPropertyForPlugin(_PLUGIN, "photoId", upload.uuid)
          end)
	else
	  rendition:uploadFailed(error_msg or 'Upload failed')
        end

        -- When done with photo, delete temp file. There is a cleanup step that happens later,
        -- but this will help manage space in the event of a large upload.
        LrFileUtils.delete( pathOrMessage )
      end
    end
  end

  progressScope:done()

end

publishServiceProvider.deletePhotosFromPublishedCollection = function( publishSettings, arrayOfPhotoIds, deletedCallback, localCollectionId )
  PhotoDeckAPI.connect(publishSettings.apiKey, publishSettings.apiSecret, publishSettings.username, publishSettings.password)
  --logger:trace('deletePhotosFromPublishedCollection')
  local catalog = LrApplication.activeCatalog()
  local collection = catalog:getPublishedCollectionByLocalIdentifier(localCollectionId)
  local galleryId = collection:getRemoteId()
  -- this next bit is stupid. Why is there no catalog:getPhotoByRemoteId or similar
  local publishedPhotos = collection:getPublishedPhotos()
  local publishedPhotoById = {}
  for _, pp in pairs(publishedPhotos) do
    publishedPhotoById[pp:getRemoteId()] = pp
  end
  for i, photoId in ipairs( arrayOfPhotoIds ) do
    local publishedPhoto = publishedPhotoById[photoId]

    local collCount = 0
    for _, c in pairs(publishedPhoto:getPhoto():getContainedPublishedCollections()) do
      if c:getRemoteId() ~= galleryId then
        collCount = collCount + 1
      end
    end

    if collCount == 0 then
      -- delete photo if this is the only collection it's in
      result, error_msg = PhotoDeckAPI.deletePhoto(photoId)

      if error_msg then
        LrErrors.throwUserError("Error deleting photo: " .. error_msg)
      end
    else
      -- otherwise unpublish from the passed in collection
      result, error_msg = PhotoDeckAPI.unpublishPhoto(photoId, galleryId)

      if error_msg then
        LrErrors.throwUserError("Error unpublishing photo: " .. error_msg)
      end
    end

    if not error_msg then
      deletedCallback(photoId)
    end
  end
end

-- no idea what actual criteria are
publishServiceProvider.validatePublishedCollectionName = function( proposedName )
  return string.match(proposedName, '^[%w:/_ -]*$')
end

publishServiceProvider.viewForCollectionSettings = function( f, publishSettings, info )
  info.collectionSettings:addObserver('display_style', onGalleryDisplayStyleSelect)
  getGalleryDisplayStyles(publishSettings, info.collectionSettings)
  local c = f:view {
    bind_to_object = info,
    spacing = f:dialog_spacing(),

    f:row {
      f:static_text {
        title = "Name:",
        width = LrView.share "collectionset_labelwidth",
      },
      f:static_text {
        title = LrView.bind 'name',
      }
    },
    f:row {
      f:static_text {
        title = "Description:",
        width = LrView.share "collectionset_labelwidth",
      },
      f:edit_field {
        bind_to_object = info.collectionSettings,
        value = LrView.bind 'description',
        width_in_chars = 40,
        height_in_chars = 5,
      }
    },
    f:row {
      f:static_text {
        title = "Gallery Style:",
        width = LrView.share "collectionset_labelwidth",
      },
      f:static_text {
        bind_to_object = info.collectionSettings,
        title = LrView.bind 'galleryDisplayStyleName',
        width_in_chars = 30,
      },
      f:push_button {
        bind_to_object = info.collectionSettings,
        action = function() chooseGalleryDisplayStyle(publishSettings, info.collectionSettings) end,
        enabled = LrBinding.keyIsNotNil 'galleryDisplayStyles',
        title = "Choose Gallery Style",
      }
    }
  }
  return c
end

publishServiceProvider.updateCollectionSettings = function( publishSettings, info )
  local urlname = publishSettings.websiteChosen
  local result, error_msg = PhotoDeckAPI.createOrUpdateGallery(urlname, info.collectionSettings.LR_liveName, info)
  if error_msg then
    LrErrors.throwUserError("Error updating gallery: " .. error_msg)
  end
end

publishServiceProvider.updateCollectionSetSettings = function( publishSettings, info )
  local urlname = publishSettings.websiteChosen
  local result, error_msg = PhotoDeckAPI.createOrUpdateGallery(urlname, info.name, info)
  if error_msg then
    LrErrors.throwUserError("Error updating gallery: " .. error_msg)
  end
end

publishServiceProvider.renamePublishedCollection = function( publishSettings, info )
  local urlname = publishSettings.websiteChosen
  local result, error_msg = PhotoDeckAPI.createOrUpdateGallery(urlname, info.name, info)
  if error_msg then
    LrErrors.throwUserError("Error renaming gallery: " .. error_msg)
  end
end

publishServiceProvider.reparentPublishedCollection = function( publishSettings, info )
  local urlname = publishSettings.websiteChosen
  local result, error_msg = PhotoDeckAPI.createOrUpdateGallery(urlname, info.name, info)
  if error_msg then
    LrErrors.throwUserError("Error reparenting gallery: " .. error_msg)
  end
end

publishServiceProvider.deletePublishedCollection = function( publishSettings, info )
  local urlname = publishSettings.websiteChosen
  local galleryId = info.remoteId
  local result, error_msg = PhotoDeckAPI.deleteGallery(urlname, galleryId)
  if error_msg then
    LrErrors.throwUserError("Error deleting gallery: " .. error_msg)
  end
end

return publishServiceProvider
