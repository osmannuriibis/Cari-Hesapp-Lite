import 'dart:async';
import 'dart:convert';

import 'package:cari_hesapp_lite/utils/place_picker_package/lib/entities/localization_item.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../place_picker.dart';
import '../uuid.dart';
import 'package:http/http.dart' as http;

/// Place picker widget made with map widget from
/// [google_maps_flutter](https://github.com/flutter/plugins/tree/master/packages/google_maps_flutter)
/// and other API calls to [Google Places API](https://developers.google.com/places/web-service/intro)
///
/// API key provided should have `Maps SDK for Android`, `Maps SDK for iOS`
/// and `Places API`  enabled for it
class PlacePicker extends StatefulWidget {
  /// API key generated from Google Cloud Console. You can get an API key
  /// [here](https://cloud.google.com/maps-platform/)
  final String apiKey;
  late final String initialSearchWord;

  /// Location to be displayed when screen is showed. If this is set or not null, the
  /// map does not pan to the user's current location.
  final LatLng? displayLocation;
  LocalizationItem? localizationItem;

  PlacePicker(this.apiKey,
      {Key? key, this.displayLocation,
      this.localizationItem,
      this.initialSearchWord = ""}) : super(key: key) {
    localizationItem ??= LocalizationItem();
  }

  @override
  State<StatefulWidget> createState() => PlacePickerState();
}

/// Place picker state
class PlacePickerState extends State<PlacePicker> {
  final Completer<GoogleMapController> mapController = Completer();

  /// Indicator for the selected location
  final Set<Marker> markers = Set();

  /// Result returned after user completes selection
  LocationResult? locationResult;

  /// Overlay to display autocomplete suggestions
  OverlayEntry? overlayEntry;

  List<NearbyPlace> nearbyPlaces = [];

  /// Session token required for autocomplete API call
  String sessionToken = Uuid().generateV4();

  GlobalKey appBarKey = GlobalKey();

  bool hasSearchTerm = false;

  String previousSearchTerm = '';

  // constructor
  PlacePickerState();

  void onMapCreated(GoogleMapController controller) {
    mapController.complete(controller);
    moveToCurrentUserLocation();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    markers.add(Marker(
      position: widget.displayLocation ?? const LatLng(5.6037, 0.1870),
      markerId: const MarkerId("selected-location"),
    ));
  }

  @override
  void dispose() {
    overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        key: appBarKey,
        title: SearchInput(searchPlace,
            initialSearchWord: widget.initialSearchWord),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.displayLocation ?? const LatLng(5.6037, 0.1870),
                zoom: 15,
              ),
              myLocationButtonEnabled: true,
              mapToolbarEnabled: true, //
              
              myLocationEnabled: true,
              onMapCreated: onMapCreated,
              onLongPress: (latLng) {
                clearOverlay();
                moveToLocation(latLng);
              },
              onTap: (latLng) {
                setState(() {
                  hasSearchTerm = !hasSearchTerm;
                });
              },
              markers: markers,
            ),
          ),
          !hasSearchTerm
              ? Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SelectPlaceAction(
                          getLocationName(),
                          () => Navigator.of(context).pop(locationResult),
                          widget.localizationItem!.tapToSelectLocation),
                      const Divider(height: 8),
                      Padding(
                        child: Text(widget.localizationItem!.nearBy,
                            style: const TextStyle(fontSize: 16)),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      ),
                      Expanded(
                        child: ListView(
                          children: nearbyPlaces
                              .map((it) => NearbyPlaceItem(
                                  it, () => moveToLocation(it.latLng!)))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  /// Hides the autocomplete overlay
  void clearOverlay() {
    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
  }

  /// Begins the search process by displaying a "wait" overlay then
  /// proceeds to fetch the autocomplete list. The bottom "dialog"
  /// is hidden so as to give more room and better experience for the
  /// autocomplete list overlay.
  void searchPlace(String place) {
    // on keyboard dismissal, the search was being triggered again
    // this is to cap that.
    if (place == previousSearchTerm) {
      return;
    }

    previousSearchTerm = place;

    if (context == null) {
      return;
    }

    clearOverlay();

    setState(() {
      hasSearchTerm = place.length > 0;
    });

    if (place.length < 1) {
      return;
    }

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    final RenderBox appBarBox =
        appBarKey.currentContext!.findRenderObject() as RenderBox;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: appBarBox.size.height,
        width: size.width,
        child: Material(
          elevation: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: <Widget>[
                const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(width: 24),
                Expanded(
                    child: Text(widget.localizationItem!.findingPlace,
                        style: const TextStyle(fontSize: 16)))
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context)!.insert(overlayEntry!);

    autoCompleteSearch(place);
  }

  /// Fetches the place autocomplete list with the query [place].
  void autoCompleteSearch(String place) async {
    try {
      place = place.replaceAll(" ", "+");

      var endpoint =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?"
          "key=${widget.apiKey}&"
          "language=${widget.localizationItem!.languageCode}&"
          "input={$place}&sessiontoken=${sessionToken}";

      if (locationResult != null) {
        endpoint += "&location=${locationResult!.latLng!.latitude}," +
            "${locationResult!.latLng!.longitude}";
      }

      final response = await http.get(Uri.parse(endpoint));

      if (response.statusCode != 200) {
        throw Error();
      }

      final responseJson = jsonDecode(response.body);

      if (responseJson['predictions'] == null) {
        throw Error();
      }

      List<dynamic> predictions = responseJson['predictions'];

      List<RichSuggestion> suggestions = [];

      if (predictions.isEmpty) {
        AutoCompleteItem aci = AutoCompleteItem();
        aci.text = widget.localizationItem!.noResultsFound;
        aci.offset = 0;
        aci.length = 0;

        suggestions.add(RichSuggestion(aci, () {}));
      } else {
        for (dynamic t in predictions) {
          final aci = AutoCompleteItem()
            ..id = t['place_id']
            ..text = t['description']
            ..offset = t['matched_substrings'][0]['offset']
            ..length = t['matched_substrings'][0]['length'];

          suggestions.add(RichSuggestion(aci, () {
            FocusScope.of(context).requestFocus(FocusNode());
            decodeAndSelectPlace(aci.id!);
          }));
        }
      }

      displayAutoCompleteSuggestions(suggestions);
    } catch (e) {
      print(e);
    }
  }

  /// To navigate to the selected place from the autocomplete list to the map,
  /// the lat,lng is required. This method fetches the lat,lng of the place and
  /// proceeds to moving the map to that location.
  void decodeAndSelectPlace(String placeId) async {
    clearOverlay();

    try {
      final url = Uri.parse(
          "https://maps.googleapis.com/maps/api/place/details/json?key=${widget.apiKey}&" +
              "language=${widget.localizationItem!.languageCode}&" +
              "placeid=$placeId");

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Error();
      }

      final responseJson = jsonDecode(response.body);

      if (responseJson['result'] == null) {
        throw Error();
      }

      final location = responseJson['result']['geometry']['location'];
      moveToLocation(LatLng(location['lat'], location['lng']));
    } catch (e) {
      print(e);
    }
  }

  /// Display autocomplete suggestions with the overlay.
  void displayAutoCompleteSuggestions(List<RichSuggestion> suggestions) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    Size size = renderBox.size;

    final RenderBox appBarBox =
        appBarKey.currentContext!.findRenderObject() as RenderBox;

    clearOverlay();

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        top: appBarBox.size.height,
        child: Material(elevation: 1, child: Column(children: suggestions)),
      ),
    );

    Overlay.of(context)!.insert(overlayEntry!);
  }

  /// Utility function to get clean readable name of a location. First checks
  /// for a human-readable name from the nearby list. This helps in the cases
  /// that the user selects from the nearby list (and expects to see that as a
  /// result, instead of road name). If no name is found from the nearby list,
  /// then the road name returned is used instead.
  String getLocationName() {
    if (locationResult == null) {
      return widget.localizationItem!.unnamedLocation;
    }

    for (NearbyPlace np in nearbyPlaces) {
      if (np.latLng == locationResult!.latLng &&
          np.name != locationResult!.locality) {
        locationResult!.name = np.name;
        return "${np.name}, ${locationResult!.locality}";
      }
    }

    return "${locationResult!.name}, ${locationResult!.locality}";
  }

  /// Moves the marker to the indicated lat,lng
  void setMarker(LatLng latLng) {
    // markers.clear();
    setState(() {
      markers.clear();
      markers.add(
          Marker(markerId: const MarkerId("selected-location"), position: latLng));
    });
  }

  /// Fetches and updates the nearby places to the provided lat,lng
  void getNearbyPlaces(LatLng latLng) async {
    try {
      final url = Uri.parse(
          "https://maps.googleapis.com/maps/api/place/nearbysearch/json?"
          "key=${widget.apiKey}&location=${latLng.latitude},${latLng.longitude}"
          "&radius=150&language=${widget.localizationItem!.languageCode}");

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Error();
      }

      final responseJson = jsonDecode(response.body);

      if (responseJson['results'] == null) {
        throw Error();
      }

      nearbyPlaces.clear();

      for (Map<String, dynamic> item in responseJson['results']) {
        final nearbyPlace = NearbyPlace()
          ..name = item['name']
          ..icon = item['icon']
          ..latLng = LatLng(item['geometry']['location']['lat'],
              item['geometry']['location']['lng']);

        nearbyPlaces.add(nearbyPlace);
      }

      // to update the nearby places
      setState(() {
        // this is to require the result to show
        hasSearchTerm = false;
      });
    } catch (e) {
      //
    }
  }

  /// This method gets the human readable name of the location. Mostly appears
  /// to be the road name and the locality.
  void reverseGeocodeLatLng(LatLng latLng) async {
    try {
      final url = Uri.parse("https://maps.googleapis.com/maps/api/geocode/json?"
          "latlng=${latLng.latitude},${latLng.longitude}&"
          "language=${widget.localizationItem!.languageCode}&"
          "key=${widget.apiKey}");

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Error();
      }

      final responseJson = jsonDecode(response.body);

      if (responseJson['results'] == null) {
        throw Error();
      }

      final result = responseJson['results'][0];

      setState(() {
        String? name,
            locality,
            postalCode,
            country,
            administrativeAreaLevel1,
            administrativeAreaLevel2,
            city,
            subLocalityLevel1,
            subLocalityLevel2;
        bool isOnStreet = false;
        if (result['address_components'] is List<dynamic> &&
            result['address_components'].length != null &&
            result['address_components'].length > 0) {
          for (var i = 0; i < result['address_components'].length; i++) {
            var tmp = result['address_components'][i];
            var types = tmp["types"] as List<dynamic>?;
            var shortName = tmp['short_name'];
            if (types == null) {
              continue;
            }
            if (i == 0) {
              // [street_number]
              name = shortName;
              isOnStreet = types.contains('street_number');
              // other index 0 types
              // [establishment, point_of_interest, subway_station, transit_station]
              // [premise]
              // [route]
            } else if (i == 1 && isOnStreet) {
              if (types.contains('route')) {
                name = (name ?? "") + ", $shortName";
              }
            } else {
              if (types.contains("sublocality_level_1")) {
                subLocalityLevel1 = shortName;
              } else if (types.contains("sublocality_level_2")) {
                subLocalityLevel2 = shortName;
              } else if (types.contains("locality")) {
                locality = shortName;
              } else if (types.contains("administrative_area_level_2")) {
                administrativeAreaLevel2 = shortName;
              } else if (types.contains("administrative_area_level_1")) {
                administrativeAreaLevel1 = shortName;
              } else if (types.contains("country")) {
                country = shortName;
              } else if (types.contains('postal_code')) {
                postalCode = shortName;
              }
            }
          }
        }
        locality = locality ?? administrativeAreaLevel1;
        city = locality;
        locationResult = LocationResult()
          ..name = name
          ..locality = locality
          ..latLng = latLng
          ..formattedAddress = result['formatted_address']
          ..placeId = result['place_id']
          ..postalCode = postalCode
          ..country = AddressComponent(name: country, shortName: country)
          ..administrativeAreaLevel1 = AddressComponent(
              name: administrativeAreaLevel1,
              shortName: administrativeAreaLevel1)
          ..administrativeAreaLevel2 = AddressComponent(
              name: administrativeAreaLevel2,
              shortName: administrativeAreaLevel2)
          ..city = AddressComponent(name: city, shortName: city)
          ..subLocalityLevel1 = AddressComponent(
              name: subLocalityLevel1, shortName: subLocalityLevel1)
          ..subLocalityLevel2 = AddressComponent(
              name: subLocalityLevel2, shortName: subLocalityLevel2);
      });
    } catch (e) {
      print(e);
    }
  }

  /// Moves the camera to the provided location and updates other UI features to
  /// match the location.
  void moveToLocation(LatLng latLng) {
    mapController.future.then((controller) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
            CameraPosition(target: latLng, zoom: 15.0)),
      );
    });

    setMarker(latLng);

    reverseGeocodeLatLng(latLng);

    getNearbyPlaces(latLng);
  }

  void moveToCurrentUserLocation() {
    if (widget.displayLocation != null) {
      moveToLocation(widget.displayLocation!);
      return;
    }

    Location().getLocation().then((locationData) {
      LatLng target = LatLng(locationData.latitude!, locationData.longitude!);
      moveToLocation(target);
    }).catchError((error) {
      // TODO: Handle the exception here
    });
  }
}
