0.10 - 03/02/2015
-----------------
Improved robustness and performance
Lightroom -> PhotoDeck photo metadata synchronization
Republishing will not reupload image again by default (see plugin settings)
PhotoDeck galleries structure synchronization
Plugin can be used in export only mode
French translations
Minor fixes

0.9 - 15/01/2015
----------------
Don't replace photos with identical file names at upload
Fix root gallery discovery when root gallery is not named "Galleries"
Reduce number of calls to PhotoDeck API
Minor fixes

0.8 - 29/12/2014
----------------
Fix republishing deleted photos
Add getPhoto API to give some details of photos, including contents
Correct published URLs for photos

0.7 - 28/12/2014
----------------
A single photo can be in multiple galleries. Changes to those photos should propagate
across all of those galleries. Uploading a photo into one gallery should not duplicate
the photo in another gallery

Allow removing an image that exists in multiple collections from a single collection.
The removal of an image in just one collection causes the deletion of the image

0.6 - 27/12/2014
----------------
Improved maintainability of galleries
- Rename gallery - also updates URL as well as name
- Reparent gallery
- Delete gallery
- Set Display Style of gallery

0.5 - 27/12/2014
----------------
Corrected bugs to improve user experience on first use

0.4 - 26/12/2014
----------------
Logging improvements

0.3 - 18/12/2014
----------------
Allow user to select the website they wish to publish to

0.2 - 18/12/2014
----------------
Ready for publishing
- Added MIT license
- Make terms more PhotoDeck specific
- Added README
- Improvements to updating photos

0.1 - 03/12/2014
----------------
Initial commit
