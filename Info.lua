return {
    LrSdkVersion = 5.7,
    LrSdkMinimumVersion = 5.0, -- minimum SDK version required by this plug-in
    LrToolkitIdentifier = 'au.id.willthames.photodeck',
    LrPluginName = 'PhotoDeck Publisher',

    LrExportServiceProvider = {
        title = "PhotoDeck", -- this string appears in the Publish Services panel
        file = "PhotoDeckPublishServiceProvider.lua", -- the service definition script
    },
    VERSION = { major=0, minor=5 },
}
