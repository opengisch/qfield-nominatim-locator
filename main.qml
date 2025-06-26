import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtCore

import org.qfield
import org.qgis
import Theme

Item {
  id: plugin

  property var mainWindow: iface.mainWindow()
  property var mapCanvas: iface.mapCanvas()

  Component.onCompleted: {
    nominatimLocatorFilter.locatorBridge.registerQFieldLocatorFilter(nominatimLocatorFilter);
  }

  Component.onDestruction: {
    nominatimLocatorFilter.locatorBridge.deregisterQFieldLocatorFilter(nominatimLocatorFilter);
  }

  Settings {
    id: settings
    category: "qfield-nominatim-locator"
    
    property string service_url: "https://nominatim.openstreetmap.org/search.php"
    property string service_crs: "EPSG:4326"
  }
  
  function configure() {
    settingsDialog.open();
  }
  
  QFieldLocatorFilter {
    id: nominatimLocatorFilter

    delay: 1000
    name: "nominatim"
    displayName: "OpenStreetMap Nominatim"
    prefix: "osm"
    locatorBridge: iface.findItemByObjectName('locatorBridge')

    parameters: {
      "service_url": settings.service_url,
      "service_crs": settings.service_crs
    }
    source: Qt.resolvedUrl('nominatim.qml')
  
    function triggerResult(result) {
      let geometry = result.userData.geometry
      if (geometry.type === Qgis.GeometryType.Point) {
        const centroid = GeometryUtils.reprojectPoint(
          GeometryUtils.centroid(geometry),
          CoordinateReferenceSystemUtils.fromDescription(parameters["service_crs"]),
          mapCanvas.mapSettings.destinationCrs
        )
        mapCanvas.mapSettings.setCenter(centroid, true);
      } else {
        const extent = GeometryUtils.reprojectRectangle(
          GeometryUtils.boundingBox(geometry),
          CoordinateReferenceSystemUtils.fromDescription(parameters["service_crs"]),
          mapCanvas.mapSettings.destinationCrs
        )
        mapCanvas.mapSettings.setExtent(extent, true);
      }
      
      locatorBridge.geometryHighlighter.qgsGeometry = geometry;
      locatorBridge.geometryHighlighter.crs = CoordinateReferenceSystemUtils.fromDescription(parameters["service_crs"]);
    }

    function triggerResultFromAction(result, actionId) {
      if (actionId === 1) {
        let navigation = iface.findItemByObjectName('navigation')
        let geometry = result.userData.geometry
        const centroid = GeometryUtils.reprojectPoint(
          GeometryUtils.centroid(geometry),
          CoordinateReferenceSystemUtils.fromDescription(parameters["service_crs"]),
          mapCanvas.mapSettings.destinationCrs
        )
        navigation.destination = centroid
      } else if (actionId === 2) {
        let feature = result.userData
        Qt.openUrlExternally("tel:" + feature.attribute("extratags")["phone"].replace(' ',''))
      }
    }
  }
  
  
  Dialog {
    id: settingsDialog
    parent: mainWindow.contentItem
    visible: false
    modal: true
    font: Theme.defaultFont
    standardButtons: Dialog.Ok | Dialog.Cancel
    title: qsTr("Nominatim search settings")

    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) / 2

    width: mainWindow.width * 0.8

    ColumnLayout {
      width: parent.width
      spacing: 10

      Label {
        id: serviceUrlLabel
        text: qsTr("Service URL")
        font: Theme.defaultFont
      }
      
      TextField {
        id: serviceUrlTextField
        Layout.fillWidth: true
        font: Theme.defaultFont
        text: settings.service_url
      }
      
      Label {
        id: serviceCrsLabel
        text: qsTr("Service CRS")
        font: Theme.defaultFont
      }
      
      TextField {
        id: serviceCrsTextField
        Layout.fillWidth: true
        font: Theme.defaultFont
        text: settings.service_crs
      }
    }

    onAccepted: {
      settings.service_url = serviceUrlTextField.text;
      settings.service_crs = serviceCrsTextField.text;
      mainWindow.displayToast(qsTr("Settings stored"));
    }
  }
}
