import QtQuick
import QtQuick.Controls

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

  QFieldLocatorFilter {
    id: nominatimLocatorFilter

    delay: 1000
    name: "nominatim"
    displayName: "OpenStreetMap Nominatim"
    prefix: "osm"
    locatorBridge: iface.findItemByObjectName('locatorBridge')

    parameters: {
      "service_url": "https://nominatim.openstreetmap.org/search.php",
      "service_crs": "EPSG:4326"
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
      
      locatorBridge.locatorHighlightGeometry.qgsGeometry = geometry;
      locatorBridge.locatorHighlightGeometry.crs = CoordinateReferenceSystemUtils.fromDescription(parameters["service_crs"]);
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
}
