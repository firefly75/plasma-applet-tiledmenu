import QtQuick
import org.kde.plasma.private.kicker as Kicker

Item {
	id: appsModel
	property alias rootModel: rootModel
	property alias allAppsModel: allAppsModel
	property alias powerActionsModel: powerActionsModel
	property alias favoritesModel: favoritesModel
	property alias tileGridModel: tileGridModel
	property alias sidebarModel: sidebarModel

	property string order: "categories"
	onOrderChanged: allAppsModel.refresh()
    



	signal refreshing()
	signal refreshed()

	Timer {
		id: rootModelRefresh
		interval: 400
		onTriggered: {
			logger.debug('rootModel.refresh.star', Date.now())
			rootModel.refresh()
			logger.debug('rootModel.refresh.done', Date.now())
		}
	}

	readonly property string recentAppsSectionLabel: {
		if (rootModel.recentOrdering == 0) {
			return i18n("Recent Apps")
		} else { // == 1
			return i18n("Most Used ")
		}
	}
	readonly property string recentAppsSectionKey: 'RECENT_APPS'

	Kicker.RootModel {
		id: rootModel
		appNameFormat: 0 // plasmoid.configuration.appNameFormat
		flat: true // isDash ? true : plasmoid.configuration.limitDepth
		// sorted: Plasmoid.configuration.alphaSort

		showSeparators: false // !isDash
		appletInterface: widget

		// showAllSubtree: true //isDash (KDE 5.8 and below)
		showAllApps: true //isDash (KDE 5.9+)
		// showAllAppsCategorized: false
		showRecentApps: true //plasmoid.configuration.showRecentApps
		showRecentDocs: false //plasmoid.configuration.showRecentDocs
		// showRecentContacts: false //plasmoid.configuration.showRecentContacts
		// showPowerSession: false
		// showFavoritesPlaceholder: true
		recentOrdering: plasmoid.configuration.recentOrdering

		autoPopulate: false // (KDE 5.9+) defaulted to true
		// paginate: false // (KDE 5.9+)

		readonly property int recentAppsIndex: 0
		readonly property int recentDocsIndex: {
			if (rootModel.showRecentDocs) {
				if (rootModel.showRecentApps) {
					return 1
				} else {
					return 0
				}
			} else {
				return -1
			}
		}
		readonly property int allAppsIndex: {
			if (rootModel.showAllApps) {
				if (rootModel.showRecentApps && rootModel.showRecentDocs) {
					return 2
				} else if (rootModel.showRecentApps || rootModel.showRecentDocs) {
					return 1
				} else {
					return 0
				}
			} else {
				return -1
			}
		}
		property int categoryStartIndex: 2 // Skip Recent Apps, All Apps
		property int categoryEndIndex: rootModel.count - 1 // Skip Power

		Component.onCompleted: {
			if (!autoPopulate) {
				rootModelRefresh.restart()
				// console.log('rootModel.refresh.star', Date.now())
				// rootModel.refresh()
				// console.log('rootModel.refresh.done', Date.now())
			}
		}


		function log() {
			// logListModel('rootModel', rootModel);
			var listModel = rootModel;
			for (var i = 0; i < listModel.count; i++) {
				var item = listModel.modelForRow(i);
				// console.log(listModel, i, item);
				logObj('rootModel[' + i + ']', item)
				// logListModel('rootModel[' + i + ']', item);
			}
		}

		onCountChanged: {
			// for (var i = 0; i < rootModel.count; i++) {
			// 	var listModel = rootModel.modelForRow(i);
			// 	if (listModel.description == 'KICKER_ALL_MODEL') {
			// 		logObj('rootModel[' + i + ']', listModel)
			// 		appsModel.allAppsList = listModel;
			// 		appsModel.refreshed()
			// 	}
			// }
			debouncedRefresh.restart()
		}
			
		onRefreshed: {
			//--- Power
			var systemModel = rootModel.modelForRow(rootModel.count - 1)
			var systemList = []
			if (systemModel) {
				powerActionsModel.parseModel(systemList, systemModel)
			} else {
				console.log('systemModel is null')
			}
			powerActionsModel.list = systemList
			sessionActionsModel.parseSourceModel(powerActionsModel)

			debouncedRefresh.restart()
		}

		// KickerAppModel is a wrapper of Kicker.FavoritesModel
		// Kicker.FavoritesModel must be a child object of RootModel.
		// appEntry.actions() looks at the parent object for parent.appletInterface and will crash plasma if it can't find it.
		// https://invent.kde.org/plasma/plasma-workspace/-/blob/master/applets/kicker/plugin/appentry.cpp#L151
		favoritesModel: KickerAppModel {
			id: favoritesModel

			Component.onCompleted: {
				// TODO:
				// Populate this model with all the 'tileModel' urls so that the Search Runner
				// will prioritize the "favorited" apps.

				// favorites = 'systemsettings.desktop,sublime-text.desktop'.split(',')
			}
		}

		property var tileGridModel: KickerAppModel {
			id: tileGridModel
		}

		property var sidebarModel: KickerAppModel {
			id: sidebarModel

			Component.onCompleted: {
				favorites = plasmoid.configuration.sidebarShortcuts
			}

			onFavoritesChanged: {
				plasmoid.configuration.sidebarShortcuts = favorites
			}
			
			property Connections configConnection: Connections {
				target: plasmoid.configuration
				function onSidebarShortcutsChanged() {
					sidebarModel.favorites = plasmoid.configuration.sidebarShortcuts
				}
			}
		}
	}

	Item {
		//--- Detect Changes
		// Changes aren't bubbled up to the RootModel, so we need to detect changes somehow.
		
		// Recent Apps
		Repeater {
			model: rootModel.count >= 0 ? rootModel.modelForRow(rootModel.recentAppsIndex) : []
			
			Item {
				Component.onCompleted: {
					 //console.log('debouncedRefreshRecentApps', index)
					if (plasmoid.configuration.showRecentApps) {
						debouncedRefreshRecentApps.restart()
					}
				}
			}
		}

		// All Apps
		Repeater { // A-Z
			model: rootModel.count >= 2 ? rootModel.modelForRow(rootModel.allAppsIndex) : []

			Item {
				property var parentModel: rootModel.modelForRow(rootModel.allAppsIndex).modelForRow(index)

				Repeater { // Aaa ... Azz (Apps)
					model: parentModel && parentModel.hasChildren ? parentModel : []

					Item {
						Component.onCompleted: {
							// console.log('depth2', index, display, model)
							debouncedRefresh.restart()
						}
					}
				}

				// Component.onCompleted: {
				// 	console.log('depth1', index, display, model)
				// }
			}
		}

		Timer {
			id: debouncedRefresh
			interval: 100
			onTriggered: allAppsModel.refresh()
		}

		Timer {
			id: debouncedRefreshRecentApps
			interval: debouncedRefresh.interval
			onTriggered: allAppsModel.refreshRecentApps()
		}
		
		Connections {
			target: plasmoid.configuration
			function onShowRecentAppsChanged() { debouncedRefresh.restart() }
			function onNumRecentAppsChanged() { debouncedRefresh.restart() }
		}
	}

	KickerListModel {
		id: powerActionsModel
		onItemTriggered: {
			// console.log('powerActionsModel.onItemTriggered')
			plasmoid.expanded = false
		}
		
		function nameByIconName(iconName) {
			var item = getByValue('iconName', iconName)
			if (item) {
				return item.name
			} else {
				return iconName
			}
		}

		function triggerByIconName(iconName) {
			var item = getByValue('iconName', iconName)
			item.parentModel.trigger(item.indexInParent, "", null)
		}
	}

	// powerActionsModel filtered to logout/lock/switch user
	property alias sessionActionsModel: sessionActionsModel
	KickerListModel {
		id: sessionActionsModel
		onItemTriggered: {
			// console.log('sessionActionsModel.onItemTriggered')
			plasmoid.expanded = false
		}

		function parseSourceModel(powerActionsModel) {
			// Filter by iconName
			var sessionActionsList = []
			var sessionIconNames = ['system-lock-screen', 'system-log-out', 'system-save-session', 'system-switch-user']
			for (var i = 0; i < powerActionsModel.list.length; i++) {
				var item = powerActionsModel.list[i];
				// console.log(item, item.iconName, sessionIconNames.indexOf(item.iconName) >= 0)
				if (sessionIconNames.indexOf(item.iconName) >= 0) {
					sessionActionsList.push(item)
				}
			}
			sessionActionsModel.list = sessionActionsList
		}
	}
	
	KickerListModel {
		id: allAppsModel
		onItemTriggered: {
			// console.log('allAppsModel.onItemTriggered')
			plasmoid.expanded = false
		}

		function getRecentApps() {
			var recentAppList = [];

			//--- populate
			var model = rootModel.modelForRow(rootModel.recentAppsIndex)
			if (model) {
				parseModel(recentAppList, model)
			} else {
				console.log('getRecentApps() recent apps model is null')
			}

			//--- filter
			recentAppList = recentAppList.filter(function(item){
				//--- filter kcmshell5 applications since they show up blank (undefined)
				if (typeof item.name === 'undefined') {
					return false;
				} else {
					return true;
				}
			});

			//--- first 5 items
			recentAppList = recentAppList.slice(0, plasmoid.configuration.numRecentApps)

			//--- section
			for (var i = 0; i < recentAppList.length; i++) {
				var item = recentAppList[i];
				item.sectionKey = recentAppsSectionKey
			}

			return recentAppList;
		}

		function refreshRecentApps() {
			// console.log('refreshRecentApps')
			if (debouncedRefresh.running) {
				// We're about to do a full refresh so don't bother doing a partial update.
				return
			}
			var recentAppList = getRecentApps();
			var recentAppCount = 5
			if (recentAppCount == recentAppList.length) {
				// Do a partial update since we're only updating properties.
				refreshing()

				// Overwrite the exisiting items.
				for (var i = 0; i < recentAppList.length; i++) {
					var item = recentAppList[i]
					//console.log('item ', i , item) 
					list[i] = item
					set(i, item)
				}

				refreshed()
			} else {
				// We'll be removing items, so just replace the entire list.
				refresh()
			}
		}

		function getCategory(rootIndex) {
			var modelIndex = rootModel.index(rootIndex, 0)
			var categoryLabel = rootModel.data(modelIndex, Qt.DisplayRole)
			var categoryIcon = rootModel.data(modelIndex, Qt.DecorationRole)
			 //console.log('categoryLabel1', categoryLabel, categoryIcon)
			var categoryModel = rootModel.modelForRow(rootIndex)
			var appList = []
			if (categoryModel) {
				parseModel(appList, categoryModel)
			} else {
				console.log('allAppsModel.getCategory', rootIndex, categoryModel, 'is null')
			}
			
			for (var i = 0; i < appList.length; i++) {
				var item = appList[i];
				item.sectionKey = categoryLabel
				item.sectionIcon = categoryIcon
			}
			return appList
		}
		function getAllCategories() {
			var appList = [];
			for (var i = rootModel.categoryStartIndex; i < rootModel.categoryEndIndex; i++) { // Skip Recent Apps, All Apps, ... and Power
			// for (var i = 0; i < rootModel.count; i++) {
				appList = appList.concat(getCategory(i))
			}
			return appList
		}

		function getAllApps() {
			//--- populate list
			var appList = [];
			var model = rootModel.modelForRow(rootModel.allAppsIndex)
			if (model) {
				parseModel(appList, model)
			} else {
				console.log('getAllApps() all apps model is null')
			}

			//--- filter
			// var powerActionsList = [];
			// var sceneUrls = [];
			// appList = appList.filter(function(item){
			// 	//--- filter multiples
			// 	if (item.url) {
			// 		if (sceneUrls.indexOf(item.url) >= 0) {
			// 			return false;
			// 		} else {
			// 			sceneUrls.push(item.url);
			// 			return true;
			// 		}
			// 	} else {
			// 		return true;
			// 		//--- filter
			// 		// if (item.parentModel.toString().indexOf('SystemModel') >= 0) {
			// 		// 	// console.log(item.description, 'removed');
			// 		// 	powerActionsList.push(item);
			// 		// 	return false;
			// 		// } else {
			// 		// 	return true;
			// 		// }
			// 	}
			// });
			// powerActionsModel.list = powerActionsList; 

			//---
			for (var i = 0; i < appList.length; i++) {
				var item = appList[i];
				if (item.name) {
					var firstCharCode = item.name.charCodeAt(0);
					if (48 <= firstCharCode && firstCharCode <= 57) { // isDigit
						item.sectionKey = '0-9';
					} else if ((33 <= firstCharCode && firstCharCode <= 47)
						|| (58 <= firstCharCode && firstCharCode <= 64)
						|| (91 <= firstCharCode && firstCharCode <= 96)
						|| (123 <= firstCharCode && firstCharCode <= 126)
					) { // isSymbol
						item.sectionKey = '&';
					} else {
						item.sectionKey = item.name.charAt(0).toUpperCase();
					}
				} else {
					item.sectionKey = '?';
				}
				// console.log(item.sectionKey, item.name)
			}

			//--- sort
			appList = appList.sort(function(a,b) {
				if (a.name && b.name) {
					return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
				} else {
					// console.log(a, b);
					return 0;
				}
			})


			return appList
		}

		function refresh() {
			refreshing()
			logger.debug("allAppsModel.refresh().star", Date.now())
			
			//--- Apps
			var appList = []
			if (appsModel.order == "categories") {
				appList = getAllCategories()
			} else {
				appList = getAllApps()
			}

			//--- Recent Apps
			if (plasmoid.configuration.showRecentApps) {
				var recentAppList = getRecentApps();
				appList = recentAppList.concat(appList); // prepend
			}

			//--- Power
			// var systemModel = rootModel.modelForRow(rootModel.count - 1)
			// var systemList = []
			// parseModel(systemList, systemModel)
			// powerActionsModel.list = systemList;

			//--- parse sectionIcons
			allAppsModel.sectionIcons = {}
			for (var i = 0; i < appList.length; i++) {
				var item = appList[i]
				if (item.sectionKey && item.sectionIcon) {
					allAppsModel.sectionIcons[item.sectionKey] = item.sectionIcon
				}
			}

			//--- apply model
			allAppsModel.list = appList;
			// allAppsModel.log();

			//--- listen for changes
			// for (var i = 0; i < runnerModel.count; i++){
			// 	var runner = runnerModel.modelForRow(i);
			// 	if (!runner.listenersBound) {
			// 		runner.countChanged.connect(debouncedRefresh.logAndRestart)
			// 		runner.dataChanged.connect(debouncedRefresh.logAndRestart)
			// 		runner.listenersBound = true;
			// 	}
			// }

			logger.debug("allAppsModel.refresh().done", Date.now())
			refreshed()
		}
	}

	function endsWith(s, substr) {
		return s.indexOf(substr) == s.length - substr.length
	}

	function launch(launcherName) {
		if (!endsWith(launcherName, '.desktop')) {
			launcherName += '.desktop'
		}
		for (var i = 0; i < allAppsModel.count; i++) {
			var item = allAppsModel.get(i);
			if (item.url && endsWith(item.url, '/' + launcherName)) {
				item.parentModel.trigger(item.indexInParent, "", null);
				break;
			}
		}
	}
}
