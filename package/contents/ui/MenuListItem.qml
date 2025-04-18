import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.draganddrop as DragAndDrop


AppToolButton {
	id: itemDelegate

	width: ListView.view.width
	implicitHeight: row.implicitHeight

	property var parentModel: typeof modelList !== "undefined" && modelList[index] ? modelList[index].parentModel : undefined
	property string modelDescription: model.name == model.description ? '' : model.description // Ignore the Comment if it's the same as the Name.
	property string description: model.url ? modelDescription : '' // 
	property bool isDesktopFile: !!(model.url && endsWith(model.url, '.desktop'))
	property bool showItemUrl: listView.showItemUrl && (!isDesktopFile || listView.showDesktopFileUrl)
	property string secondRowText: showItemUrl && model.url ? model.url : modelDescription
	property bool secondRowVisible: secondRowText
	property string launcherUrl: model.favoriteId || model.url
	property string iconName: model.iconName || ''
	property alias iconSource: itemIcon.source
	property int iconSize: model.largeIcon ? listView.iconSize * 2 : listView.iconSize

	function endsWith(s, substr) {
		return s.indexOf(substr) == s.length - substr.length
	}

	// We need to look at the js list since ListModel doesn't support item's with non primitive propeties (like an Image).
	property bool modelListPopulated: !!listView.model.list && listView.model.list.length - 1 >= index
	//property var iconInstance: modelListPopulated && listView.model.list[index] ? listView.model.list[index].icon : ""
//	property var iconInstance: {
//     if (modelListPopulated && listView.model.list[index]) {
//         var item = listView.model.list[index];
//         // Try to access the icon in different ways
//         if (item.icon !== undefined) {
//             return item.icon;
//         } else if (item.decoration !== undefined) {
//             return item.decoration;
//         } else if (item.iconName !== undefined) {
//             return Qt.icon.fromTheme(item.iconName);
//         } else {
//             console.log("Debug - available properties:", Object.keys(item));
//             return "";
//         }
//     } else {
//         return "";
//     }
// }
//      Kirigami.Icon {
// 		id: testname
//         source: iconName  // This uses the theme icon name directly
//     }
	// Connections {
	// 	target: listView.model
	// 	function onRefreshed() {
			
	// 		// We need to manually trigger an update when we update the model without replacing the list.
	// 		// Otherwise the icon won't be in sync.
	// 		itemDelegate.iconInstance = listView.model.list[index] ? listView.model.list[index].icon : ""
	// 	}
	// }

	// Drag (based on kicker)
	// https://github.com/KDE/plasma-desktop/blob/4aad3fdf16bc5fd25035d3d59bb6968e06f86ec6/applets/kicker/package/contents/ui/ItemListDelegate.qml#L96
	// https://github.com/KDE/plasma-desktop/blob/master/applets/kicker/plugin/draghelper.cpp
	property int pressX: -1
	property int pressY: -1
	property bool dragEnabled: launcherUrl
	function initDrag(mouse) {
		pressX = mouse.x
		//console.log("init drag")
		pressY = mouse.y
	}
	function shouldStartDrag(mouse) {
		return dragEnabled
			&& pressX != -1 // Drag initialized?
			&& dragHelper.isDrag(pressX, pressY, mouse.x, mouse.y) // Mouse moved far enough?
	}
	function startDrag() {
		// Note that we fallback from url to favoriteId for "Most Used" apps.
		
		var dragIcon = iconSource
		//console.log("start drag ", dragHelper.defaultIcon , dragIcon)
		//if (typeof dragIcon === "string") {
			//console.log("start drag ",dragHelper.defaultIcon)
			// startDrag must use QIcon. See Issue #75.
		  //   dragIcon = dragHelper.defaultIcon
			//dragIcon = null
		//}
		// console.log('startDrag', widget, model.url, "favoriteId", model.favoriteId)
		// console.log('    iconInstance', iconInstance)
		// console.log('    dragIcon', dragIcon)
		//if (dragIcon) {
			
			dragHelper.startDrag(widget, model.url || model.favoriteId, dragIcon, "favoriteId", model.favoriteId)
		//}

		resetDragState()
	}
	function resetDragState() {
		pressX = -1
		pressY = -1
	}
	onPressed: function(mouse) {
		//("click menu ", model.iconName)
		if (mouse.buttons & Qt.LeftButton) {
			initDrag(mouse)
		}
	}
	onContainsMouseChanged: function(containsMouse) {
		if (!containsMouse) {
			resetDragState()
		}
	}
	onPositionChanged: function(mouse) {
		if (shouldStartDrag(mouse)) {
			startDrag()
		}
	}

	RowLayout { // ItemListDelegate
		id: row
		anchors.left: parent.left
		anchors.leftMargin: Kirigami.Units.smallSpacing
		anchors.right: parent.right
		anchors.rightMargin: Kirigami.Units.smallSpacing

		Item {
			Layout.fillHeight: true
			implicitHeight: itemIcon.implicitHeight
			implicitWidth: itemIcon.implicitWidth

			Kirigami.Icon {
				id: itemIcon
				anchors.centerIn: parent
				implicitHeight: itemDelegate.iconSize
				implicitWidth: implicitHeight

				// visible: iconsEnabled

				animated: true
				// usesPlasmaTheme: false
				source: itemDelegate.iconName || itemDelegate.iconInstance
			}
		}

		ColumnLayout {
			Layout.fillWidth: true
			// Layout.fillHeight: true
			Layout.alignment: Qt.AlignVCenter
			spacing: 0

			RowLayout {
				Layout.fillWidth: true
				// height: itemLabel.height

				PlasmaComponents3.Label {
					id: itemLabel
					text: model.name
					maximumLineCount: 1
					// elide: Text.ElideMiddle
					height: implicitHeight
				}

				PlasmaComponents3.Label {
					Layout.fillWidth: true
					text: !itemDelegate.secondRowVisible ? itemDelegate.description : ''
					color: config.menuItemTextColor2
					maximumLineCount: 1
					elide: Text.ElideRight
					height: implicitHeight // ElideRight causes some top padding for some reason
				}
			}

			PlasmaComponents3.Label {
				visible: itemDelegate.secondRowVisible
				Layout.fillWidth: true
				// Layout.fillHeight: true
				text: itemDelegate.secondRowText
				color: config.menuItemTextColor2
				maximumLineCount: 1
				elide: Text.ElideMiddle
				height: implicitHeight
			}
		}

	}

	acceptedButtons: Qt.LeftButton | Qt.RightButton
	onClicked: function(mouse) {
		mouse.accepted = true
		resetDragState()
		logger.debug('MenuListItem.onClicked', mouse.button, Qt.LeftButton, Qt.RightButton)
		if (mouse.button == Qt.LeftButton) {
			trigger()
		} else if (mouse.button == Qt.RightButton) {
			contextMenu.open(mouse.x, mouse.y)
		}
	}

	function trigger() {
		listView.model.triggerIndex(index)
	}

	// property bool hasActionList: listView.model.hasActionList(index)
	// property var actionList: hasActionList ? listView.model.getActionList(index) : []
	AppContextMenu {
		id: contextMenu
		onPopulateMenu: function(menu) {
			if (launcherUrl && !plasmoid.configuration.tilesLocked) {
				menu.addPinToMenuAction(launcherUrl)
			}
			if (listView.model.hasActionList(index)) {
				var actionList = listView.model.getActionList(index)
				menu.addActionList(actionList, listView.model, index)
			}
		}
	}

} // delegate: AppToolButton
