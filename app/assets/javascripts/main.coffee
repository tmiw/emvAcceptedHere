if not MainApp?
    MainApp = exports? and exports or @MainApp = {}
else
    MainApp = @MainApp
    
class MainApp.MainController extends SimpleMVC.Controller
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
                
                pinImage = new google.maps.MarkerImage(window.emv.image_urls[pinColor],
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
                hideChains: $("#hideChains").prop("checked")
                showPayAtTable: $("#showPayAtTable").prop("checked")
                showGasPumps: $("#showGasPumps").prop("checked")
                showUnattendedTerminals: $("#showUnattendedTerminals").prop("checked")
                
        # Google Analytics notification so it can tell the session is active.
        ga('send', 'event', {
            'eventCategory': 'map',
            'eventAction': 'move'
        })

        if $("#showAsHeatmap").prop("checked") == true
            query = $.ajax "/heatmap/" + mapNE.lat() + "/" + mapNE.lng() + "/" + mapSW.lat() + "/" + mapSW.lng(), settings
        else
            query = $.ajax "/businesses/" + mapNE.lat() + "/" + mapNE.lng() + "/" + mapSW.lat() + "/" + mapSW.lng(), settings
        self = this
        if this._heatmap?
            this._heatmap.setData({
                min: 0
                max: 100
                data: []
            })
        if $("#showAsHeatmap").prop("checked") == true
            query.done (data) ->
                # Unlike the below, we're getting all of the EMV enabled points available 
                # in the current view (with lat/lon capped to 2 decimal places). Create the
                # heatmap instance, if not already done, and feed the data into it for rendering.
                if not self._heatmap?
                    self._heatmap = new HeatmapOverlay(self._map, {
                        radius: 0.01
                        scaleRadius: true
                        useLocalExtrema: false
                        latField: "lat"
                        lngField: "lng"
                        valueField: "count"
                    })
                
                found_max = 0
                for v in data
                    v.lat = parseFloat(v.lat)
                    v.lng = parseFloat(v.lng)
                    v.count = parseInt(v.count)
                    if v.count > found_max
                        found_max = v.count
                
                self._heatmap.setData({
                    min: 0
                    max: found_max
                    data: data
                })
                
                # Clear all existing points from map since we want to only show the heatmap.
                for key, val of self._locations
                    val.marker.marker.setMap null
                    
                self._locations = {}
        else
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
                                gas_pump_working: i.gas_pump_working == "true"
                                pay_at_table: i.pay_at_table == "true"
                                quick_chip: i.quick_chip == "true"
                                unattended_terminals: i.unattended_terminals == "true"
                            }
                    
                        if Object.keys(self._locations[latlon].businesses).length > 1
                            self._locations[latlon].onlyOneBusiness = false
                    else
                        # Need to add new entry for this location
                        newobj = {}
                        newobj.notSeen = false
                        newobj.needToCreatePin = true
                        newobj.edit_disabled = true
                        newobj.onlyOneBusiness = true
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
                            gas_pump_working: i.gas_pump_working == "true"
                            pay_at_table: i.pay_at_table == "true"
                            quick_chip: i.quick_chip == "true"
                            unattended_terminals: i.unattended_terminals == "true"
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
                    if self._place? 
                        centerLocString = self._place.geometry.location.lat() + "," + self._place.geometry.location.lng()
                        placeName = self._place.name
                        if self._place.formatted_address.indexOf(placeName) > -1
                            placeName = ""
                    else
                        placeName = ""
                        centerLocString = self._cur_lat + "," + self._cur_lon
                    found = false
                    for k, v of self._locations
                        loc = null
                        for id, l of v.businesses
                            loc = l
                        locString = loc.lat + "," + loc.lon
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
                                    gas_pump_working: false
                                    pay_at_table: false
                                    quick_chip: false
                                    unattended_terminals: false
        
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

        if self._infoWindow?
            self._infoWindow.close()
                    
        this._place = this._autocomplete.getPlace()
        placeLoc = this._place.geometry.location
        window.app.navigate "/loc/" + placeLoc.lat() + "/" + placeLoc.lng(), true, false
        this._handlePossibleAdd = true
        google.maps.event.addListener this._map, "bounds_changed", this._navigateDebounce
        this._map.setZoom 15
    
    reportError: (id) ->
        this._reportId = id
        
        # Only show report popup here; doReport() will actually submit.
        $("#report-reason").val("")
        $("#report-overlay").css("display", "block")
        
    doReport: () ->
        if $("#report-reason").val() == ""
            alert("A reason must be provided in order to submit a report.")
        else
            query = $.ajax "/businesses/report/" + this._reportId, {type: "POST", data: {
                reason: $("#report-reason").val()
                submitter_email: $("#report-email").val()
            }}
            
            $("#report-overlay").css("display", "none")
            self = this
            query.done () ->
                $("#report-errors-" + self._reportId).text("reported")
    
    cancelReport: () ->
        $("#report-overlay").css("display", "none")
    
    showMapOptions: () ->
        $("#options-overlay").css("display", "block")
        
    cancelOptions: () ->
        $("#options-overlay").css("display", "none")
        
    getDrivingDirections: (addr) ->
        src = this._cur_lat + "," + this._cur_lon
        encoded_dest = encodeURI(addr)
        window.open "http://maps.apple.com/?daddr=" + encoded_dest + "&saddr=" + src
    
    addNewBusiness: (id) ->
        # Clear form and make it editable.
        $("#businessName").val("")
        $("#businessName").prop("disabled", false)
        $("#pinEnabled").prop("disabled", false)
        $("#pinEnabled").prop("checked", false)
        $("#contactlessEnabled").prop("disabled", false)
        $("#contactlessEnabled").prop("checked", false)
        $("#gasPumpWorking").prop("disabled", false)
        $("#gasPumpWorking").prop("checked", false)
        $("#payAtTable").prop("disabled", false)
        $("#payAtTable").prop("checked", false)
        $("#quickChip").prop("disabled", false)
        $("#quickChip").prop("checked", false)
        $("#unattendedTerminals").prop("disabled", false)
        $("#unattendedTerminals").prop("checked", false)
        $("#addBusinessLink").css("display", "inline")
        $("#addNewBusinessLink").css("display", "none")
        $("#wikiLink").css("display", "none")
        $("#getDirectionsLink").css("display", "none")
        $("#report-errors-" + id).css("display", "none")
        
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
            gas_pump_working = $("#gasPumpWorking").prop("checked")
            pay_at_table = $("#payAtTable").prop("checked")
            unattended_terminals = $("#unattendedTerminals").prop("checked")
            quick_chip = $("#quickChip").prop("checked")
            request = $.ajax "/businesses/add", {type: "POST", data: {
                name: $("#businessName").val(),
                address: $("#businessAddress").text(),
                latitude: this._place.geometry.location.lat(),
                longitude: this._place.geometry.location.lng(),
                pin_enabled: pin_enabled,
                contactless_enabled: contactless_enabled,
                gas_pump_working: gas_pump_working,
                pay_at_table: pay_at_table,
                quick_chip: quick_chip,
                unattended_terminals: unattended_terminals
            }}
            request.done (data) ->
                self._infoWindow.close()
            
                key = data.lat + "," + data.lng
                if self._locations[key]?
                    self._locations[key].needToCreatePin = true
                    self._locations[key].onlyOneBusiness = false
                    self._locations[key].businesses[data.id] =
                        id: data.id
                        name: data.name
                        address: data.address
                        lat: data.lat
                        lon: data.lng
                        pin_enabled: data.pin_enabled == "true" or data.pin_enabled == true
                        contactless_enabled: data.contactless_enabled == "true" or data.contactless_enabled == true
                        gas_pump_working: data.gas_pump_working == "true" or data.gas_pump_working == true
                        pay_at_table: data.pay_at_table == "true" or data.pay_at_table == true
                        unattended_terminals: data.unattended_terminals == "true" or data.unattended_terminals == true
                        quick_chip: data.quick_chip == "true" or data.quick_chip == true
                        confirmed_location: true
                else
                    view = 
                        edit_disabled: true
                        onlyOneBusiness: true
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
                        gas_pump_working: data.gas_pump_working == "true" or data.gas_pump_working == true
                        pay_at_table: data.pay_at_table == "true" or data.pay_at_table == true
                        unattended_terminals: data.unattended_terminals == "true" or data.unattended_terminals == true
                        quick_chip: data.quick_chip == "true" or data.quick_chip == true
                        confirmed_location: true
                    
                    self._locations[key] = view

                self._createMarkersForBusinesses()

    @route "loc/:lat/:long", (lat, lng) ->
        mapOptions = {
            zoom: 5,
            center: new google.maps.LatLng(lat, lng),
            noClear: true
        }
        if this._first_nav
            mapOptions.zoom = 15
            this._handlePossibleAdd = true
            this._first_nav = false
        if not this._map?
            this._map = new google.maps.Map(document.getElementById("map-canvas"), mapOptions)
            
            # handler so we can reload the list
            google.maps.event.addListener this._map, "bounds_changed", this._navigateDebounce
        
            # initialize autocomplete widget
            this._autocomplete = new google.maps.places.Autocomplete(
            	document.getElementById("address"),
            	{componentRestrictions: {country: 'us'}}
            )
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
                    self._map.setZoom 15
                    window.app.navigate "/loc/" + pos.coords.latitude + "/" + pos.coords.longitude, true, false
                
                options = 
                    maximumAge: 1000 * 60 * 30
                    
                navigator.geolocation.getCurrentPosition successFn, self._goDefaultHome, options
        , 0)
        
    @route "", () ->
        # Load saved state of hide checkbox and attach event handler
        self = this
        $(".noscriptmsg").css("display", "none");
        $(".site-container").css("display", "block");
        if window.localStorage.getItem('hideUnconfirmed') == "true"
            $("#hideUnconfirmed").prop("checked", true)
        if window.localStorage.getItem('hideChains') == "true"
            $("#hideChains").prop("checked", true)
        if window.localStorage.getItem('showGasPumps') == "true"
            $("#showGasPumps").prop("checked", true)
        if window.localStorage.getItem('showPayAtTable') == "true"
            $("#showPayAtTable").prop("checked", true)
        if window.localStorage.getItem('showUnattendedTerminals') == "true"
            $("#showUnattendedTerminals").prop("checked", true)
        if window.localStorage.getItem('showAsHeatmap') == "true"
            $("#showAsHeatmap").prop("checked", true)
            $("#address").prop("disabled", true)
            
        $("#hideUnconfirmed").change(() -> 
            window.localStorage.setItem('hideUnconfirmed', $("#hideUnconfirmed").prop("checked"))
            self._navigateDebounce())
        $("#hideChains").change(() -> 
            window.localStorage.setItem('hideChains', $("#hideChains").prop("checked"))
            self._navigateDebounce())
        $("#showGasPumps").change(() -> 
            window.localStorage.setItem('showGasPumps', $("#showGasPumps").prop("checked"))
            if window.localStorage.getItem('showGasPumps') == "true"
                # Restaurants cannot have gas pumps too. Hopefully.
                $("#showPayAtTable").prop("disabled", true)
            else
                $("#showPayAtTable").prop("disabled", false)
            self._navigateDebounce())
        $("#showPayAtTable").change(() -> 
            window.localStorage.setItem('showPayAtTable', $("#showPayAtTable").prop("checked"))
            if window.localStorage.getItem('showPayAtTable') == "true"
                # Restaurants cannot have gas pumps too. Hopefully.
                $("#showGasPumps").prop("disabled", true)
            else
                $("#showGasPumps").prop("disabled", false)
            self._navigateDebounce())
        $("#showUnattendedTerminals").change(() -> 
            window.localStorage.setItem('showUnattendedTerminals', $("#showUnattendedTerminals").prop("checked"))
            self._navigateDebounce())
        $("#showAsHeatmap").change(() -> 
            window.localStorage.setItem('showAsHeatmap', $("#showAsHeatmap").prop("checked"))
            if $("#showAsHeatmap").prop("checked") == true
                $("#address").prop("disabled", true)
            else
                $("#address").prop("disabled", false)
            self._navigateDebounce())
            
        if window.location.hash
            # We're going to navigate directly to a particular location on the map.
            hash_without_hash = window.location.hash.substring 1
            components = hash_without_hash.split ","
            if components.length == 2
                self._cur_lat = components[0]
                self._cur_lon = components[1]
                self._first_nav = true
                window.app.navigate "/loc/" + components[0] + "/" + components[1], true, false
            else
                self._goDefaultHome()        
                self.goHome()
        else
            # Navigate to center of the US to start. Geolocation will move us to the correct location later.        
            self._goDefaultHome()        
            self.goHome()

