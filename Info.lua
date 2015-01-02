return {
    LrSdkVersion = 3.0,
    LrSdkMinimumVersion = 3.0, -- minimum SDK version required by this plug-in
    LrToolkitIdentifier = 'au.id.willthames.photodeck',
    LrPluginName = 'PhotoDeck Publisher',
    LrPluginInfoUrl = 'https://github.com/willthames/photodeck.lrdevplugin',

    LrExportServiceProvider = {
        title = "PhotoDeck", -- this string appears in the Publish Services panel
        file = "PhotoDeckPublishServiceProvider.lua", -- the service definition script
    },
    VERSION = { major=0, minor=8, revision=1 },
}
