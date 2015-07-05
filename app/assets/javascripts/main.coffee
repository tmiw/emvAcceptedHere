class MainController extends SimpleMVC.Controller
    _navigateDebounce: () =>
        if this._navTimeoutId?
            clearTimeout this._navTimeoutId
        
        this._navTimeoutId = setTimeout this._navigateToNewBounds, 100
    
    _createMarkersForBusinesses: () =>
        for key, val of this._locations
            if val.needToCreatePin
                if Object.keys(val.businesses).length > 1
                    # Multiple businesses at this location
                    pinColor = "yellow"
                    for k, v of val.businesses
                    	lat = v.lat
                    	lon = v.lon
                else
                    entry = null
                    for k, v of val.businesses
                        entry = v
                    lat = entry.lat
                    lon = entry.lon
                    if v.confirmed_location
                        pinColor = "green"
                    else
                        pinColor = "red"
                
                pinImage = new google.maps.MarkerImage("/assets/images/" + pinColor + "-pin.png",
                    new google.maps.Size(21, 34),
                    new google.maps.Point(0,0),
                    new google.maps.Point(10, 34))
                    
                newMarker = {
                    marker: new google.maps.Marker({
                        position: new google.maps.LatLng(lat, lon),
                        map: this._map,
                        icon: pinImage
                    }),
                    infoWindow: new google.maps.InfoWindow({
                    	content: "<div id='x'></div>"
                    })
                }
                
                val.needToCreatePin = false
                val.marker = newMarker
                
                aMarker = newMarker.marker
                aMarker._____refToSelf = newMarker
                aMarker._____refToSelf.infoWindow.ourStuff = val
                self = this
                google.maps.event.addListener aMarker, "click", () ->
                    if self._infoWindow?
                        self._infoWindow.close()
                    self._infoWindow = this._____refToSelf.infoWindow
                    self._place = 
                        geometry:
                            location: this.getPosition()
                    this._____refToSelf.infoWindow.open self._map, this._____refToSelf.marker
                
                # This event handler dynamically generates the info window.
                google.maps.event.addListener newMarker.infoWindow, "domready", () ->
                    self._infoWindow.setContent('<div id="x"></div>')
                    x = document.getElementById('x')
                    if x
                        x.innerHTML = templates.per_item_entry(self._infoWindow.ourStuff)
                    self._infoWindow.ourStuff.foundPlaceName = ""
                        
    _navigateToNewBounds: () =>
        this._navTimeoutId = undefined
        
        # Set not seen flag so we know which ones to remove later
        if not this._locations?
            this._locations = {}
        else
            for latlon, data of this._locations
                data.notSeen = true
        
        mapBounds = this._map.getBounds()
        mapNE = mapBounds.getNorthEast()
        mapSW = mapBounds.getSouthWest()
        
        settings = 
            data:
                hideUnconfirmed: $("#hideUnconfirmed").prop("checked")
                
        query = $.ajax "/businesses/" + mapNE.lat() + "/" + mapNE.lng() + "/" + mapSW.lat() + "/" + mapSW.lng(), settings
        self = this
        query.done (data) ->
            # Add new data to in-memory representation and mark entries that have not been
            # removed.
            for i in data
                latlon = i.lat + "," + i.lng
                if self._locations[latlon]?
                    self._locations[latlon].notSeen = false
                    
                    if not self._locations[latlon].businesses[i.id]
                        self._locations[latlon].businesses[i.id] = {
                            id: i.id
                            name: i.name
                            address: i.address
                            lat: i.lat
                            lon: i.lng
                            pin_enabled: i.pin_enabled == "true"
                            contactless_enabled: i.contactless_enabled == "true"
                            confirmed_location: i.confirmed_location == "true"
                        }
                else
                    # Need to add new entry for this location
                    newobj = {}
                    newobj.notSeen = false
                    newobj.needToCreatePin = true
                    newobj.edit_disabled = true
                    newobj.businesses = {}
                    newobj.businesses[i.id] = {
                        id: i.id
                        name: i.name
                        address: i.address
                        lat: i.lat
                        lon: i.lng
                        pin_enabled: i.pin_enabled == "true"
                        contactless_enabled: i.contactless_enabled == "true"
                        confirmed_location: i.confirmed_location == "true"
                    }
                    self._locations[latlon] = newobj
            
            # Remove unmarked entries from map
            toKeep = {}
            for key, val of self._locations
                if val.notSeen
                    val.marker.marker.setMap null
                else
                    toKeep[key] = val
            
            self._locations = toKeep
            
            # Create markers for newly downloaded businesses
            self._createMarkersForBusinesses()
            
            if self._handlePossibleAdd
                self._handlePossibleAdd = false 
                placeName = self._place.name
                if self._place.formatted_address.indexOf(placeName) > -1
                    placeName = ""
                found = false
                for k, v of self._locations
                	loc = null
                	for id, l of v.businesses
                        loc = l
                    locString = loc.lat + "," + loc.lon
                    centerLocString = self._place.geometry.location.lat() + "," + self._place.geometry.location.lng()
                    if locString == centerLocString
                        v.foundPlaceName = placeName
                        self._infoWindow = v.marker.infoWindow
                        v.marker.infoWindow.open self._map, v.marker.marker
                        found = true

                if not found
                    view = 
                        edit_disabled: false
                        businesses: 
                            0:
                                id: 0
                                name: placeName
                                address: self._place.formatted_address
                                pin_enabled: false
                                contactless_enabled: false
        
                    if self._infoWindow?
                        self._infoWindow.close()
        
                    self._infoWindow = new google.maps.InfoWindow({
                        position: self._place.geometry.location
                        content: "<div id='x'></div>"
                    })
                    
                    google.maps.event.addListener self._infoWindow, "domready", () ->
                        self._infoWindow.setContent('<div id="x"></div>')
                        x = document.getElementById('x')
                        if x
                            x.innerHTML = templates.per_item_entry(view)
                            
                    self._infoWindow.open self._map

    _navigateToAddress: () =>
        # Ensure event isn't called multiple times.
        google.maps.event.clearListeners this._map, "bounds_changed"

        this._place = this._autocomplete.getPlace()
        placeLoc = this._place.geometry.location
        window.app.navigate "/loc/" + placeLoc.lat() + "/" + placeLoc.lng(), true, false
        this._handlePossibleAdd = true
        google.maps.event.addListener this._map, "bounds_changed", this._navigateDebounce
        this._map.setZoom 15
    
    reportError: (id) ->
        result = ""
        while result == ""
            result = window.prompt("Enter reason for reporting this entry:")
        if result != null
            query = $.ajax "/businesses/report/" + id, {type: "POST", data: {
                reason: result
            }}
            query.done () ->
                $("#report-errors-" + id).text("reported")
    
    getDrivingDirections: (addr) ->
        src = this._cur_lat + "," + this._cur_lon
        encoded_dest = encodeURI(addr)
        window.open "http://maps.apple.com/?daddr=" + encoded_dest + "&saddr=" + src
    
    addBusiness: () ->
        self = this
        validated = true
        if $("#businessName").val() == ""
            alert "Name must be filled in before you can add this business to the map."
            validated = false
        locString = this._place.geometry.location.lat() + "," + this._place.geometry.location.lng()
        if this._locations[locString]?
            for k,v of this._locations[locString].businesses
                if v.name == $("#businessName").val()
                    alert "Cannot add duplicate business at this location."
                    validated = false
        if validated
            pin_enabled = $("#pinEnabled").prop("checked")
            contactless_enabled = $("#contactlessEnabled").prop("checked")
            request = $.ajax "/businesses/add", {type: "POST", data: {
                name: $("#businessName").val(),
                address: $("#businessAddress").text(),
                latitude: this._place.geometry.location.lat(),
                longitude: this._place.geometry.location.lng(),
                pin_enabled: pin_enabled,
                contactless_enabled: contactless_enabled,
            }}
            request.done (data) ->
                self._infoWindow.close()
            
                key = data.lat + "," + data.lng
                if self._locations[key]?
                    self._locations[key].businesses[data.id] =
                        id: data.id
                        name: data.name
                        address: data.address
                        lat: data.lat
                        lon: data.lng
                        pin_enabled: data.pin_enabled == "true" or data.pin_enabled == true
                        contactless_enabled: data.contactless_enabled == "true" or data.contactless_enabled == true
                        confirmed_location: true
                    
                    # Make marker yellow since there are now 2+ items at the same lat/lon
                    self._locations[key].marker.marker.setIcon(
                        new google.maps.MarkerImage("/assets/images/yellow-pin.png",
                            new google.maps.Size(21, 34),
                            new google.maps.Point(0,0),
                            new google.maps.Point(10, 34)))
                else
                    view = 
                        edit_disabled: true
                        needToCreatePin: true
                        businesses: {}
                
                    view.businesses[data.id] =
                        id: data.id
                        name: data.name
                        address: data.address
                        lat: data.lat
                        lon: data.lng
                        pin_enabled: data.pin_enabled == "true" or data.pin_enabled == true
                        contactless_enabled: data.contactless_enabled == "true" or data.contactless_enabled == true
                        confirmed_location: true
                    
                    self._locations[key] = view

                self._createMarkersForBusinesses()

    @route "loc/:lat/:long", (lat, lng) ->
        mapOptions = {
            zoom: 5,
            center: new google.maps.LatLng(lat, lng),
            noClear: true
        }
        if not this._map?
            this._map = new google.maps.Map(document.getElementById("map-canvas"), mapOptions)
            
            # handler so we can reload the list
            google.maps.event.addListener this._map, "bounds_changed", this._navigateDebounce
        
            # initialize autocomplete widget
            this._autocomplete = new google.maps.places.Autocomplete(document.getElementById("address"))
            google.maps.event.addListener this._autocomplete, 'place_changed', this._navigateToAddress
        else
            this._map.panTo mapOptions.center
    
    _goDefaultHome: (errObj) ->
        self._cur_lat = 39.828175
        self._cur_lon = -98.579500
        window.app.navigate "/loc/39.828175/-98.579500", true, false
        
    goHome: () ->
        self = this

        setTimeout(() ->
            if navigator.geolocation?
                successFn = (pos) ->
                    self._cur_lat = pos.coords.latitude
                    self._cur_lon = pos.coords.longitude
                    self._map.setZoom 10
                    window.app.navigate "/loc/" + pos.coords.latitude + "/" + pos.coords.longitude, true, false
                
                options = 
                    maximumAge: 1000 * 60 * 30
                    
                navigator.geolocation.getCurrentPosition successFn, self._goDefaultHome, options
        , 0)
        
    @route "", () ->
        # Load saved state of hide checkbox and attach event handler
        self = this
        if window.localStorage.getItem('hideUnconfirmed') == "true"
            $("#hideUnconfirmed").prop("checked", true)
        $("#hideUnconfirmed").change(() -> 
            window.localStorage.setItem('hideUnconfirmed', $("#hideUnconfirmed").prop("checked"))
            self._navigateDebounce())
        
        # Navigate to center of the US to start. Geolocation will move us to the correct location later.
        self._goDefaultHome()        
        self.goHome()
            
# initialize app
google.maps.event.addDomListener window, "load", () ->
    window.app = new MainController
    window.app.start()
