// Shared overlay for the Spotify application scene; never a system Dynamic Island.
#import <UIKit/UIKit.h>

#define SGKeyYanbiMiniIsland @"spotifyglass.vitrine.miniIsland"

// Call on the main thread after Spotify's UIKit startup is available.
void SGYanbiIslandInstall(void);
// Re-read the switch and current scene without restarting Spotify.
void SGYanbiIslandRefresh(void);
