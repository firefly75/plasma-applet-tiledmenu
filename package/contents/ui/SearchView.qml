import QtQuick

Item {
	id: searchView
	implicitWidth: config.appAreaWidth
	// Behavior on implicitWidth {
	// 	NumberAnimation { duration: 400 }
	// }

	visible: opacity > 0
	opacity: config.showSearch ? 1 : 0
	// Behavior on opacity {
	// 	NumberAnimation { duration: 400 }
	// }

	Connections {
		target: search
		function onIsSearchingChanged() {
			if (search.isSearching) {
				searchView.showSearchView()
			}
		}
	}
	clip: true

	property alias searchResultsView: searchResultsView
	property alias appsView: appsView
	property alias tileEditorView: tileEditorViewLoader.item
	property alias tileEditorViewLoader: tileEditorViewLoader
	property alias searchField: searchField
	property alias jumpToLetterView: jumpToLetterView

	readonly property bool showingOnlyTiles: !config.showSearch
	readonly property bool showingAppList: stackView.currentItem == appsView || stackView.currentItem == jumpToLetterView
	readonly property bool showingAppsAlphabetically: config.showSearch && appsModel.order == "alphabetical" && showingAppList
	readonly property bool showingAppsCategorically: config.showSearch && appsModel.order == "categories" && showingAppList
	readonly property bool showSearchField: config.hideSearchField ? !!searchField.text : true

	readonly property bool searchOnTop: config.searchOnTop

	function showDefaultView() {
		//console.log('asd ' , plasmoid.configuration.defaultAppListView)
		var defView = plasmoid.configuration.defaultAppListView
		if (defView == 'Alphabetical') {
			appsView.showAppsAlphabetically()
			config.showSearch = true
		} else if (defView == 'Categories') {
			appsView.showAppsCategorically()
			config.showSearch = true
		} else if (defView == 'JumpToLetter') {
			jumpToLetterView.showLetters()
			config.showSearch = true
		} else if (defView == 'JumpToCategory') {
			jumpToLetterView.showCategories()
			config.showSearch = true
		} else if (defView == 'TilesOnly') {
			searchView.showTilesOnly()
		}
		
	}

	function showTilesOnly() {
		if (!showingAppList) {
			// appsView.show(stackView.noTransition)
		
			appsView.show()
			
		}
		plasmoid.configuration.defaultAppListView = 'TilesOnly'
		config.showSearch = false
	}

	function showSearchView() {
		config.showSearch = true
	}

	states: [
		State {
			name: "searchOnTop"
			when: searchOnTop
			PropertyChanges {
				target: stackViewContainer
				anchors.topMargin: searchField.visible ? searchField.height: 0
			}
			PropertyChanges {
				target: searchField
				anchors.top: searchField.parent.top
				
			}
		},
		State {
			name: "searchOnBottom"
			when: !searchOnTop
			PropertyChanges {
				target: stackViewContainer
				anchors.bottomMargin: searchField.visible ? searchField.height : 0
			}
			PropertyChanges {
				target: searchField
				anchors.top: stackViewContainerplasmoid.configuration.defaultAppListView.bottom
				
			}
		}
	]


	Item {
		id: stackViewContainer
		anchors.fill: parent

	     

		SearchResultsView {
			id: searchResultsView
			visible: false

			Connections {
				target: search
				function onQueryChanged() {
					if (search.query.length > 0 && stackView.currentItem != searchResultsView) {
						stackView.replace(searchResultsView)
					}
					searchResultsView.filterViewOpen = false
				}
			}
            
            
          
			onVisibleChanged: {
				if (!visible) { // !stackView.currentItem
					search.query = ""
				}
			}

			function showDefaultSearch() {
				if (stackView.currentItem != searchResultsView) {
					stackView.replace(searchResultsView)
				}
				search.applyDefaultFilters()
			}
		}
		
		AppsView {
			id: appsView
			visible: false

			function showAppsAlphabetically() {
				appsModel.order = "alphabetical"
				//console.log('config search size', stackViewContainer.top, ' this ' , appsView.height)
				plasmoid.configuration.defaultAppListView = 'Alphabetical'
				show()
			}

			function showAppsCategorically() {
				appsModel.order = "categories"
				plasmoid.configuration.defaultAppListView = 'Categories'
				
				show()
			}

			function show(animation) {
				config.showSearch = true
				if (stackView.currentItem != appsView) {
					// stackView.delegate = animation || stackView.panUp
					stackView.replace(appsView)
				}
				appsView.scrollToTop()
			}
		}

		JumpToLetterView {
			id: jumpToLetterView
			visible: false
			
			function showLetters() {
				appsModel.order = "alphabetical"
				
				show()
			}

			function showCategories() {
				appsModel.order = "categories"
				show()
			}

			function show() {
				config.showSearch = true
				if (stackView.currentItem != jumpToLetterView) {
					// stackView.delegate = stackView.zoomOut
					stackView.replace(jumpToLetterView)
				}
			}
		}

		Loader {
			id: tileEditorViewLoader
			source: "TileEditorView.qml"
			visible: false
			active: false
			// asynchronous: true
			function open(tile) {
				config.showSearch = true
				active = true
				item.open(tile)
			}
			readonly property bool isCurrentView: stackView.currentItem == tileEditorView
			onIsCurrentViewChanged: {
				config.isEditingTile = isCurrentView
			}
		}

		SearchStackView {
			id: stackView
			anchors.fill: parent
			initialItem: appsView
		}
	}
    

	SearchField {
		id: searchField
		visible: !config.isEditingTile && searchView.showSearchField
		height: config.searchFieldHeight
		width: parent.width - 40
		anchors.left: parent.left
		//anchors.right: parent.right 

		listView: stackView.currentItem && stackView.currentItem.listView ? stackView.currentItem.listView : []
	}
}
