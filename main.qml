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

  readonly property var presets: [
    { name: "OpenStreetMap", url: "https://nominatim.openstreetmap.org/search.php", crs: "EPSG:4326" }
  ]

  function getPresetByName(name) {
    return presets.find(p => p.name === name);
  }

  function getActivePreset() {
    return getPresetByName(settings.service_endpoint) || presets[0];
  }

  Component.onCompleted: {
    nominatimLocatorFilter.locatorBridge.registerQFieldLocatorFilter(nominatimLocatorFilter);
  }

  Component.onDestruction: {
    nominatimLocatorFilter.locatorBridge.deregisterQFieldLocatorFilter(nominatimLocatorFilter);
  }

  Settings {
    id: settings
    category: "qfield-nominatim-locator"

    property string service_endpoint: "OpenStreetMap"
    property string service_crs: ""
    property string service_custom_url: ""
    property string service_custom_url_history: "[]"
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
      "service_url": settings.service_custom_url || plugin.getActivePreset().url,
      "service_crs": settings.service_crs || plugin.getActivePreset().crs
    }
    source: Qt.resolvedUrl('nominatim.qml')

    Component.onCompleted: {
      if (nominatimLocatorFilter.description !== undefined) {
        nominatimLocatorFilter.description = "Returns OpenStreetMap Nominatim search results."
      }
    }

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

    property var urlHistory: []

    function loadHistory() {
      try {
        urlHistory = JSON.parse(settings.service_custom_url_history);
        if (!Array.isArray(urlHistory)) urlHistory = [];
      } catch (e) {
        urlHistory = [];
      }
    }

    function saveToHistory(url, crs) {
      urlHistory = urlHistory.filter(e => e.url !== url);
      urlHistory.unshift({ url: url, crs: crs });
      if (urlHistory.length > 10) urlHistory.length = 10;
      settings.service_custom_url_history = JSON.stringify(urlHistory);
    }

    function deleteFromHistory() {
      const url = customUrlCombo.editText.trim();
      urlHistory = urlHistory.filter(e => e.url !== url);
      settings.service_custom_url_history = JSON.stringify(urlHistory);
      updateCustomUrlCombo();
    }

    function updateCustomUrlCombo() {
      customUrlCombo.model = urlHistory.map(e => e.url);
    }

    function updateUI() {
      const isCustom = endpointCombo.currentText === qsTr("Custom");
      customUrlRow.visible = isCustom;

      if (isCustom) {
        updateCustomUrlCombo();
        const currentUrl = customUrlCombo.editText.trim();
        const saved = urlHistory.find(e => e.url === currentUrl);
        serviceCrsTextField.text = saved ? saved.crs : (settings.service_crs || plugin.getActivePreset().crs);

        Qt.callLater(() => {
          customUrlCombo.forceActiveFocus();
          Qt.inputMethod.show();
        });
      } else {
        const preset = plugin.getPresetByName(endpointCombo.currentText);
        if (preset) {
          serviceCrsTextField.text = preset.crs;
        }
      }
    }

    onOpened: {
      loadHistory();

      let endpointItems = presets.map(p => p.name);
      endpointItems.push(qsTr("Custom"));
      endpointCombo.model = endpointItems;

      const isCustom = settings.service_custom_url !== "";
      if (isCustom) {
        endpointCombo.currentIndex = endpointCombo.model.length - 1;
        customUrlCombo.editText = settings.service_custom_url;
      } else {
        const idx = endpointCombo.model.indexOf(settings.service_endpoint);
        endpointCombo.currentIndex = idx !== -1 ? idx : 0;
      }

      updateUI();
    }

    ColumnLayout {
      width: parent.width
      spacing: 10

      Label {
        id: serviceUrlLabel
        text: qsTr("Service URL")
        font: Theme.defaultFont
      }

      ComboBox {
        id: endpointCombo
        Layout.fillWidth: true
        font: Theme.defaultFont
        onActivated: settingsDialog.updateUI()
      }

      RowLayout {
        id: customUrlRow
        Layout.fillWidth: true
        spacing: 8
        visible: false

        ComboBox {
          id: customUrlCombo
          Layout.fillWidth: true
          font: Theme.defaultFont
          editable: true
          onEditTextChanged: settingsDialog.updateUI()
        }

        QfToolButton {
          id: deleteButton
          bgcolor: "transparent"
          iconSource: Theme.getThemeVectorIcon("ic_delete_forever_white_24dp")
          iconColor: Theme.mainTextColor
          onClicked: {
            settingsDialog.deleteFromHistory();
            mainWindow.displayToast(qsTr("Removed URL"));
          }
        }
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
        placeholderText: qsTr("e.g., EPSG:4326")
      }
    }

    onAccepted: {
      const crs = serviceCrsTextField.text.trim();

      if (!crs) {
        mainWindow.displayToast(qsTr("CRS is required"));
        return;
      }

      const isCustom = endpointCombo.currentText === qsTr("Custom");

      if (isCustom) {
        const url = customUrlCombo.editText.trim();
        if (!url) {
          mainWindow.displayToast(qsTr("URL is required"));
          return;
        }
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
          mainWindow.displayToast(qsTr("Invalid URL entered"));
          return;
        }

        settings.service_endpoint = "Custom";
        settings.service_custom_url = url;
        settings.service_crs = crs;
        saveToHistory(url, crs);
        mainWindow.displayToast(qsTr("Settings stored"));
      } else {
        const preset = plugin.getPresetByName(endpointCombo.currentText);
        settings.service_endpoint = endpointCombo.currentText;
        settings.service_custom_url = "";
        settings.service_crs = crs;

        if (preset && crs !== preset.crs) {
          mainWindow.displayToast(qsTr("Preset CRS changed"));
        } else {
          mainWindow.displayToast(qsTr("Settings stored"));
        }
      }
    }
  }
}
