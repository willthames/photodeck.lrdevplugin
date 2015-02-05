local LrApplication = import 'LrApplication'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrErrors = import 'LrErrors'
local LrHttp = import 'LrHttp'

local logger = import 'LrLogger'( 'PhotoDeckPublishLightroomPlugin' )

logger:enable('logfile')

local PhotoDeckAPI = require 'PhotoDeckAPI'
local PhotoDeckUtils = require 'PhotoDeckUtils'
local printTable = PhotoDeckUtils.printTable
local filter = PhotoDeckUtils.filter
local map = PhotoDeckUtils.map

local publishServiceProvider = {}

-- General plugin configuration for export & publish operations
publishServiceProvider.hideSections = { 'exportLocation' }
publishServiceProvider.allowFileFormats = { 'JPEG', 'TIFF', 'Original' }
publishServiceProvider.hidePrintResolution = true

-- General plugin configuration for publish operations
publishServiceProvider.supportsIncrementalPublish = true
publishServiceProvider.small_icon = 'photodeck16.png'
publishServiceProvider.titleForPublishedCollection = LOC("$$$/PhotoDeck/Publish/Collection=Gallery")
publishServiceProvider.titleForPublishedCollectionSet = LOC("$$$/PhotoDeck/Publish/CollectionSet=Folder")
publishServiceProvider.titleForGoToPublishedCollection = LOC("$$$/PhotoDeck/Publish/GoToCollection=Go to PhotoDeck Gallery")
publishServiceProvider.titleForGoToPublishedPhoto =  LOC("$$$/PhotoDeck/Publish/GoToPhoto=Go to Photo in PhotoDeck Gallery")
publishServiceProvider.disableRenamePublishedCollectionSet = true

-- these fields get stored between uses
publishServiceProvider.exportPresetFields = {
  { key = 'username', default = "" },
  { key = 'password', default = "" },
  { key = 'apiKey', default = "" },
  { key = 'apiSecret', default = "" },
  { key = 'websiteChosen', default = "" },
  { key = 'uploadOnRepublish', default = false }
}

local function  updateApiKeyAndSecret(propertyTable)
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

local function onWebsiteSelect(propertyTable, key, value)
  propertyTable.websiteName = propertyTable.websites[value].title
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
    title = LOC "$$$/PhotoDeck/GalleryDisplayStylesDialog/Title=Gallery Display Styles",
    contents = c,
  })
  return propertyTable
end

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
        onWebsiteSelect(propertyTable, nil, propertyTable.websiteChosen)
      end

      -- show synchronization message if in progress
      if not propertyTable.canSynchronize then
        propertyTable.synchronizeGalleriesResult = LOC("$$$/PhotoDeck/SynchronizeStatus/InProgress=In progress^.")
      end
    end
  end, 'PhotoDeckAPI Login')
end

local function synchronizeGalleries(propertyTable)
  propertyTable.synchronizeGalleriesResult = LOC("$$$/PhotoDeck/SynchronizeStatus/Starting=Starting^.")
  propertyTable.canSynchronize = false
  LrTasks.startAsyncTask(function()
    PhotoDeckAPI.connect(propertyTable.apiKey, propertyTable.apiSecret, propertyTable.username, propertyTable.password)
    local result, error_msg = PhotoDeckAPI.synchronizeGalleries(propertyTable.websiteChosen, propertyTable)
    if error_msg then
      propertyTable.synchronizeGalleriesResult = error_msg
    elseif result then
      if result.created == 0 and result.deleted == 0 and result.errors == 0 then
        propertyTable.synchronizeGalleriesResult = LOC("$$$/PhotoDeck/SynchronizeStatus/FinishedWithNoChanges=Finished, no changes")
      else
        propertyTable.synchronizeGalleriesResult = LOC("$$$/PhotoDeck/SynchronizeStatus/FinishedWithChanges=Finished: ^1 created, ^2 deleted, ^3 errors", result.created, result.deleted, result.errors)
      end
    else
      propertyTable.synchronizeGalleriesResult = "?"
    end
    propertyTable.canSynchronize = true
  end, 'PhotoDeckAPI galleries synchronization')
end

local function onGalleryDisplayStyleSelect(propertyTable, key, value)
  local chosenStyle = filter(propertyTable.galleryDisplayStyles, function(v) return v.value == value end)
  if #chosenStyle > 0 then
    propertyTable.galleryDisplayStyleName = chosenStyle[1].title
  end
end

function publishServiceProvider.startDialog(propertyTable)
  propertyTable.loggedin = false
  propertyTable.websiteChoices = {}
  propertyTable.galleryDisplayStyles = {}
  propertyTable.multipleWebsites = false
  propertyTable.websiteName = ''
  propertyTable.canSynchronize = PhotoDeckAPI.canSynchronize
  propertyTable.synchronizeGalleriesResult = ''

  local keysAreValid = PhotoDeckAPI.hasDistributionKeys or (
    propertyTable.apiKey and propertyTable.apiKey ~= '' and
    propertyTable.apiSecret and propertyTable.apiSecret ~= '')

  if not keysAreValid then
    propertyTable = updateApiKeyAndSecret(propertyTable)
  end
  if propertyTable.username and propertyTable.username ~= '' and
     propertyTable.password and propertyTable.password ~= '' and
     keysAreValid then
    login(propertyTable)
  else
    ping(propertyTable)
  end

  propertyTable:addObserver('websiteChosen', onWebsiteSelect)
end

function publishServiceProvider.sectionsForTopOfDialog( f, propertyTable )
  -- LrMobdebug.on()
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
          action = function() propertyTable = updateApiKeyAndSecret(propertyTable) end,
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
	    visible = LrBinding.andAllKeys('LR_publishService', 'loggedin'),
            title = LOC "$$$/PhotoDeck/AccountDialog/Website=Website:",
            width = LrView.share "user_label_width",
            alignment = 'right'
          },
          f:static_text {
	    visible = LrBinding.andAllKeys('LR_publishService', 'loggedin'),
            title = LrView.bind 'websiteName',
            width = 300,
          }
        },
      },

      f:column {
        f:push_button {
          title = LOC "$$$/PhotoDeck/AccountDialog/WebsiteChangeAction=Change",
	  visible = LrBinding.andAllKeys('LR_publishService', 'loggedin'),
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
        title = LOC "$$$/PhotoDeck/PublishOptionsDialog/SynchronizeGalleriesAction=Import existing PhotoDeck galleries",
        action = function()
                   if not propertyTable.LR_publishService then
		     -- publish service is not created yet (this is a new unsaved plugin instance)
		     LrDialogs.message(LOC "$$$/PhotoDeck/PublishOptionsDialog/SaveFirst=Please save the settings first!")
	           else
		     local result = LrDialogs.confirm(
		       LOC "$$$/PhotoDeck/PublishOptionsDialog/ConfirmTitle=This will import and connect your existing PhotoDeck galleries structure in Lightroom.",
		       LOC "$$$/PhotoDeck/PublishOptionsDialog/ConfirmSubtitle=Galleries that are already connected won't be touched.^nGallery content is currently not imported.",
		       LOC "$$$/PhotoDeck/PublishOptionsDialog/ProceedAction=Proceed",
		       LOC "$$$/PhotoDeck/PublishOptionsDialog/CancelAction=Cancel")
		     if result == "ok" then
                       synchronizeGalleries(propertyTable)
		     end
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

local function getPhotoDeckPhotoIdsStoredInCatalog(photo)
  local str = photo:getPropertyForPlugin(_PLUGIN, "photoId")
  if not str then
    return {}
  end

  local res = {}
  for elem in string.gmatch(str, "%S+") do
    local key = nil
    local val = nil
    local i = 0
    local pkv = {}
    for kv in string.gmatch(elem, '[^:]+') do
      i = i + 1
      pkv[i] = kv
    end
    if pkv[1] then
      if pkv[2] then
	key = pkv[1]
	val = pkv[2]
      else
	key = ''
	val = pkv[1]
      end
    end
    if key then
      res[key] = val
    end
  end

  for k,v in pairs(res) do
  end

  return res
end

local function storePhotoDeckPhotoIdsInCatalog(photo, websiteuuid, photouuid)
  local curr = getPhotoDeckPhotoIdsStoredInCatalog(photo)
  curr[websiteuuid] = photouuid
  local str = ''
  for k, v in pairs(curr) do
    if k and k ~= '' then
      str = str .. tostring(k) .. ':' .. tostring(v) .. ' '
    else
      str = str .. tostring(v) .. ' '
    end
  end
  photo:setPropertyForPlugin(_PLUGIN, "photoId", str)
end


function publishServiceProvider.processRenderedPhotos( functionContext, exportContext )
  logger:trace('publishServiceProvider.processRenderedPhotos')

  local exportSession = exportContext.exportSession
  local exportSettings = assert( exportContext.propertyTable )
  local isPublish = exportSettings.LR_isExportForPublish
  local nPhotos = exportSession:countRenditions()
  local catalog = exportSession.catalog
  local error_msg

  PhotoDeckAPI.connect(exportSettings.apiKey, exportSettings.apiSecret, exportSettings.username, exportSettings.password)

  -- Set progress title.
  local progressScope = exportContext:configureProgress {
    title = nPhotos > 1
    and LOC("$$$/PhotoDeck/ProcessRenderedPhotos/Progress=Publishing ^1 photos to PhotoDeck", nPhotos)
    or LOC "$$$/PhotoDeck/ProcessRenderedPhotos/Progress/One=Publishing one photo to PhotoDeck",
  }

  -- Look for a gallery id for this collection.
  local urlname = exportSettings.websiteChosen
  local gallery = nil
  local websiteuuid = nil

  if isPublish then
    website, error_msg = PhotoDeckAPI.website(urlname)
    if not website or error_msg then
      progressScope:done()
      LrErrors.throwUserError(LOC("$$$/PhotoDeck/ProcessRenderedPhotos/ErrorGettingWebsite=Error retrieving website: ^1", error_msg))
      return
    end
    websiteuuid = website.uuid
    local collectionInfo = exportContext.publishedCollectionInfo
    local galleryId = collectionInfo.remoteId
    local galleryPhotos
  
    if galleryId then
      gallery, error_msg = PhotoDeckAPI.gallery(urlname, galleryId)
      if error_msg then
        progressScope:done()
        LrErrors.throwUserError(LOC("$$$/PhotoDeck/ProcessRenderedPhotos/ErrorGettingGallery=Error retrieving gallery: ^1", error_msg))
        return
      end
    end
  
    if not gallery then
      -- Create or update this gallery.
      if not collectionInfo.publishedCollection then
        collectionInfo.publishedCollection = exportContext.publishedCollection
      end
      gallery, error_msg = PhotoDeckAPI.createOrUpdateGallery(urlname, collectionInfo)
      if error_msg then
        progressScope:done()
        LrErrors.throwUserError(LOC("$$$/PhotoDeck/ProcessRenderedPhotos/ErrorCreatingGallery=Error creating gallery: ^1", error_msg))
        return
      end
    end
  end

  -- Iterate through photo renditions.
  local uploadedPhotoIds = {}
  for i, rendition in exportContext:renditions { stopIfCanceled = true } do
    -- Update progress scope.
    progressScope:setPortionComplete( ( i - 1 ) / nPhotos )

    -- Get next photo.
    local photo = rendition.photo
    local photoId = nil
    local catalogKey = nil

    -- See if we previously uploaded this photo.
    if isPublish then
      photoId = rendition.publishedPhotoId or uploadedPhotoIds[photo.localIdentifier]
      local isVirtualCopy = photo:getRawMetadata('isVirtualCopy')
      if isVirtualCopy then
        -- virtual copy shares the same metadata catalog entries it seems, so we use a different key to store the PhotoDeck ID
        catalogKey = websiteuuid .. "/" .. tostring(photo.localIdentifier)
      else
        catalogKey = websiteuuid
      end
      if not photoId then
        -- previously published in another gallery?
        catalog:withReadAccessDo( function()
          local photoIds = getPhotoDeckPhotoIdsStoredInCatalog(photo)
	  if isVirtualCopy then
            photoId = photoIds[catalogKey]
          else
            photoId = photoIds[catalogKey] or photoIds['']
	  end
        end)
      end
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

	local upload
	if not error_msg then
          -- Build list of photo attributes
          local photoAttributes = {}
  
          if not photoAlreadyPublished or exportSettings.uploadOnRepublish then
            photoAttributes.contentPath = pathOrMessage
          end
          photoAttributes.publishToGallery = gallery.uuid
          photoAttributes.lrPhoto = photo
  
          -- Upload or replace/update the photo.
          if photoAlreadyPublished then
            upload, error_msg = PhotoDeckAPI.updatePhoto(photoId, urlname, photoAttributes, true)
	    if upload and upload.notfound then
	      -- Not found error on PhotoDeck. Assume that the photo is gone and that we need to upload it again.
	      photoAlreadyPublished = false
	      photoAttributes.contentPath = pathOrMessage
	    end
	  end

          if not photoAlreadyPublished then
            upload, error_msg = PhotoDeckAPI.uploadPhoto(urlname, photoAttributes)
          end
        end

	if not error_msg and upload and upload.uuid and upload.uuid ~= "" then
	  if isPublish then
            rendition:recordPublishedPhotoId(upload.uuid)

	    -- Also save the remote photo ID at the LrPhoto level, so that we can find it when publishing in a different gallery
	    catalog:withWriteAccessDo( "publish", function( context )
              storePhotoDeckPhotoIdsInCatalog(photo, catalogKey, upload.uuid)
            end)
          end

	  -- Remember this in the list of photos we uploaded.
	  uploadedPhotoIds[photo.localIdentifier] = upload.uuid

	else
	  rendition:uploadFailed(error_msg or LOC("$$$/PhotoDeck/ProcessRenderedPhotos/ErrorUploading=Upload failed"))
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
  logger:trace('publishServiceProvider.deletePhotosFromPublishedCollection')
  PhotoDeckAPI.connect(publishSettings.apiKey, publishSettings.apiSecret, publishSettings.username, publishSettings.password)
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
    error_msg = nil
    if photoId ~= "" then
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
          LrErrors.throwUserError(LOC("$$$/PhotoDeck/DeletePhotos/ErrorDeletingPhoto=Error deleting photo: ^1", error_msg))
        end
      else
        -- otherwise unpublish from the passed in collection
        result, error_msg = PhotoDeckAPI.unpublishPhoto(photoId, galleryId)
  
        if error_msg then
          LrErrors.throwUserError(LOC("$$$/PhotoDeck/DeletePhotos/ErrorUnpublishingPhoto=Error unpublishing photo: ^1", error_msg))
        end
      end
    end

    if not error_msg then
      deletedCallback(photoId)
    end
  end
end

publishServiceProvider.validatePublishedCollectionName = function( proposedName )
  -- string needs to be valid UTF-8 (3 multibyte chars max) and less than 200 bytes
  local length = string.len(proposedName)
  return length > 0 and length < 200
end

publishServiceProvider.metadataThatTriggersRepublish = function( publishSettings )
  return {
    default = false,
    rating = true,
    title = true,
    caption = true,
    creator = true,
    keywords = true,
    dateCreated = true,
    headline = true,
    iptcSubjectCode = true,
    dateCreated = true,
    location = true,
    city = true,
    stateProvince = true,
    country = true,
    copyright = true,
    customMetadata = false
  }
end

publishServiceProvider.viewForCollectionSettings = function( f, publishSettings, info )
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

publishServiceProvider.updateCollectionSettings = function( publishSettings, info )
  logger:trace('publishServiceProvider.updateCollectionSettings')
  PhotoDeckAPI.connect(publishSettings.apiKey, publishSettings.apiSecret, publishSettings.username, publishSettings.password)
  local urlname = publishSettings.websiteChosen
  local result, error_msg = PhotoDeckAPI.createOrUpdateGallery(urlname, info, true)
  if error_msg then
    LrErrors.throwUserError(LOC("$$$/PhotoDeck/UpdateCollection/ErrorUpdatingGallery=Error updating gallery: ^1", error_msg))
  end
end

publishServiceProvider.updateCollectionSetSettings = function( publishSettings, info )
  logger:trace('publishServiceProvider.updateCollectionSetSettings')
  PhotoDeckAPI.connect(publishSettings.apiKey, publishSettings.apiSecret, publishSettings.username, publishSettings.password)
  local urlname = publishSettings.websiteChosen
  local result, error_msg = PhotoDeckAPI.createOrUpdateGallery(urlname, info, true)
  if error_msg then
    LrErrors.throwUserError(LOC("$$$/PhotoDeck/UpdateCollection/ErrorUpdatingGallery=Error updating gallery: ^1", error_msg))
  end
end

publishServiceProvider.renamePublishedCollection = function( publishSettings, info )
  logger:trace('publishServiceProvider.renamePublishedCollection')
  PhotoDeckAPI.connect(publishSettings.apiKey, publishSettings.apiSecret, publishSettings.username, publishSettings.password)
  local urlname = publishSettings.websiteChosen
  local result, error_msg = PhotoDeckAPI.createOrUpdateGallery(urlname, info)
  if error_msg then
    LrErrors.throwUserError(LOC("$$$/PhotoDeck/UpdateCollection/ErrorRenamingGallery=Error renaming gallery: ^1", error_msg))
  end
end

publishServiceProvider.reparentPublishedCollection = function( publishSettings, info )
  logger:trace('publishServiceProvider.reparentPublishedCollection')
  PhotoDeckAPI.connect(publishSettings.apiKey, publishSettings.apiSecret, publishSettings.username, publishSettings.password)
  local urlname = publishSettings.websiteChosen
  local result, error_msg = PhotoDeckAPI.createOrUpdateGallery(urlname, info)
  if error_msg then
    LrErrors.throwUserError(LOC("$$$/PhotoDeck/UpdateCollection/ErrorReparentingGallery=Error reparenting gallery: ^1", error_msg))
  end
end

publishServiceProvider.deletePublishedCollection = function( publishSettings, info )
  logger:trace('publishServiceProvider.deletePublishedCollection')
  PhotoDeckAPI.connect(publishSettings.apiKey, publishSettings.apiSecret, publishSettings.username, publishSettings.password)
  local urlname = publishSettings.websiteChosen
  local galleryId = info.remoteId
  local result, error_msg = PhotoDeckAPI.deleteGallery(urlname, galleryId)
  if error_msg then
    LrErrors.throwUserError(LOC("$$$/PhotoDeck/DeleteCollection/ErrorDeletingGallery=Error deleting gallery: ^1", error_msg))
  end
end

publishServiceProvider.goToPublishedPhoto = function( publishSettings, info )
  logger:trace('publishServiceProvider.goToPublishedPhoto')
  local catalog = LrApplication.activeCatalog()

  -- The following is just ugly and not robust, but Lightroom doesn't gives us the LrPublishedCollection object, just it's name and parents.
  -- So we need to go to it's parent and find the parent children that matches the collection name...
  local publishedCollectionParent = info.publishService
  for _, parent in pairs(info.publishedCollectionInfo.parents) do
    publishedCollectionParent = catalog:getPublishedCollectionByLocalIdentifier(parent.localCollectionId)
  end
  local publishedCollection = nil
  for _, collection in pairs(publishedCollectionParent:getChildCollections()) do
    if collection:getName() == info.publishedCollectionInfo.name then
      publishedCollection = collection
      break
    end
  end
  
  if publishedCollection then
    local galleryurl = publishedCollection:getRemoteUrl()
    if galleryurl and galleryurl ~= '' then
      local url = galleryurl .. '/-/medias/' .. info.remoteId
      logger:trace('Opening ' .. url)
      LrHttp.openUrlInBrowser(url)
    else
      LrErrors.throwUserError(LOC("$$$/PhotoDeck/GoToPublishedPhoto/GalleryUrlNotFound=Gallery address is not known yet"))
    end
  else
    LrErrors.throwUserError(LOC("$$$/PhotoDeck/GoToPublishedPhoto/CollectionNotFound=Error finding collection"))
  end
end

return publishServiceProvider
