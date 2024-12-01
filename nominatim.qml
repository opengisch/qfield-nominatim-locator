import QtQuick
import org.qfield

Item {
  signal prepareResult(var details)
  signal fetchResultsEnded()
  
  function fetchResults(string, context, parameters) {
    if (parameters["service_url"] === undefined || string === "") {
      fetchResultsEnded();
    }
    console.log('Fetching results....');
    
    let request = new XMLHttpRequest();
    request.onreadystatechange = function() {
      if (request.readyState === XMLHttpRequest.DONE) {
        let features = FeatureUtils.featuresFromJsonString(request.response)
        for (let feature of features) {
          let address = feature.attribute("address")
          let addressDetails = []

          if (address["house_humber"] !== undefined && address["house_number"] !== "")
          {
            addressDetails.push(address["house_humber"])
          }
          if (address["road"] !== undefined && address["road"] !== "")
          {
            addressDetails.push(address["road"])
          }
          if (address["village"] !== undefined && address["village"] !== "")
          {
            addressDetails.push(address["village"])
          }
          if (address["city_district"] !== undefined && address["city_district"] !== "")
          {
            addressDetails.push(address["city_district"])
          }
          if (address["town"] !== undefined && address["town"] !== "")
          {
            addressDetails.push(address["town"])
          }
          if (address["city"] !== undefined && address["city"] !== "")
          {
            addressDetails.push(address["city"])
          }
          if (address["state"] !== undefined && address["state"] !== "")
          {
            addressDetails.push(address["state"])
          }
          if (address["country"] !== undefined && address["country"] !== "")
          {
            addressDetails.push(address["country"])
          }

          let details = {
            "userData": feature,
            "displayString": feature.attribute('name'),
            "description": addressDetails.join(', '),
            "score": 1,
            "group": feature.attribute('category').replace('_', ' ') + ': ' + feature.attribute('type').replace('_', ' '),
            "groupScore":1,
            "actions":[]
          }
          let actions = []
          let extratags = feature.attribute("extratags")
          if (extratags["phone"] !== undefined && extratags["phone"] !== "") {
            details["actions"].push({
              "id": 2,
              "name": "Call",
              "icon": Qt.resolvedUrl("phone.svg")
            })
          }
          details["actions"].push({
            "id": 1,
            "name": "Set as destination",
            "icon": "qrc:/themes/qfield/nodpi/ic_navigation_flag_purple_24dp.svg"
          })
          prepareResult(details);
        }
        fetchResultsEnded()
      }
    }
    let viewbox = GeometryUtils.reprojectRectangle(context.targetExtent, context.targetExtentCrs, CoordinateReferenceSystemUtils.fromDescription(parameters["service_crs"])).toString().replace(" : ", ",")
    request.open("GET", parameters["service_url"] + "?q=" + encodeURIComponent(string) + '&viewbox=' + viewbox + '&format=geojson&extratags=1&addressdetails=1&limit=20')
    request.send();
  }
}
