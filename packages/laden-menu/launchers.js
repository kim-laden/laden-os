// Laden OS launchers: Kickoff ("Laden menu", Meta) + Application Dashboard (fullscreen).
// Used by laden-menu-apply (existing desktops) and the Laden panel template (new users).
var LADEN_FAVORITES = [%FAVORITES%];
function ladenSetupKickoff(w) {
    w.currentConfigGroup = [];
    w.writeConfig("popupWidth", 980);
    w.writeConfig("popupHeight", 700);
    w.currentConfigGroup = ["General"];
    w.writeConfig("icon", "laden-menu");
    w.writeConfig("menuLabel", "");
    w.writeConfig("favoritesDisplay", 0);       // favourites as a grid
    w.writeConfig("applicationsDisplay", 1);    // apps as a list next to the category rail
    w.writeConfig("switchCategoryOnHover", true);
    w.writeConfig("highlightNewlyInstalledApps", true);
    w.writeConfig("showActionButtonCaptions", false);
    w.writeConfig("favorites", LADEN_FAVORITES);
    w.writeConfig("favoritesPortedToKAstats", false);
}
function ladenSetupDashboard(w) {
    w.currentConfigGroup = ["General"];
    w.writeConfig("icon", "laden-dashboard");
    w.writeConfig("alphaSort", false);      // keep the Laden category order
    w.writeConfig("showRecentApps", true);
    w.writeConfig("showRecentDocs", false);
    w.writeConfig("favoriteApps", LADEN_FAVORITES);
    w.writeConfig("favoritesPortedToKAstats", false);
    w.globalShortcut = "Meta+Shift+Space";
}
