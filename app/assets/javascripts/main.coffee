class MainController extends SimpleMVC.Controller
    _navigateDebounce: () =>
        if this._navTimeoutId?
            clearTimeout this._navTimeoutId
        
        this._navTimeoutId = setTimeout this._navigateToNewBounds, 100
        
    _navigateToNewBounds: () =>
        this._navTimeoutId = undefined
        
        # Set not seen flag so we know which ones to remove later
        if not this._locations?
            this._locations = []
        else
            for i in this._locations
                i.notSeen = true
        
        mapBounds = this._map.getBounds()
        mapNE = mapBounds.getNorthEast()
        mapSW = mapBounds.getSouthWest()
        
        query = $.ajax "/businesses/" + mapNE.lat() + "/" + mapNE.lng() + "/" + mapSW.lat() + "/" + mapSW.lng()
        self = this
        query.done (data) ->
            for i in data
                notExists = true
                for j in self._locations
                    if i.id == j.id
                        j.notSeen = false
                        notExists = false

                if notExists
                    view = 
                        id: i.id
                        name: i.name
                        address: i.address
                        pin_enabled: i.pin_enabled == "true"
                        contactless_enabled: i.contactless_enabled == "true"
                        edit_disabled: true
                    
                    windowContents = Mustache.render(templates.per_item_entry, view)
                                        
                    if i.confirmed_location != "true"
                        pinColor = "FE7569";
                    else
                        pinColor = "00FF00"
                    
                    pinImage = new google.maps.MarkerImage("http://chart.apis.google.com/chart?chst=d_map_pin_letter&chld=%E2%80%A2|" + pinColor,
                        new google.maps.Size(21, 34),
                        new google.maps.Point(0,0),
                        new google.maps.Point(10, 34))
                    pinShadow = new google.maps.MarkerImage("http://chart.apis.google.com/chart?chst=d_map_pin_shadow",
                        new google.maps.Size(40, 37),
                        new google.maps.Point(0, 0),
                        new google.maps.Point(12, 35))
                        
                    newMarker = {
                        marker: new google.maps.Marker({
                            position: new google.maps.LatLng(i.lat, i.lng),
                            map: self._map,
                            icon: pinImage,
                            shadow: pinShadow
                        }),
                        infoWindow: new google.maps.InfoWindow({
                            content: windowContents
                        }),
                        notSeen: false,
                        id: i.id
                    }
                    aMarker = newMarker.marker
                    aMarker._____refToSelf = newMarker
                    google.maps.event.addListener aMarker, "click", () ->
                        if self._infoWindow?
                            self._infoWindow.close()
                        this._____refToSelf.infoWindow.open self._map, this._____refToSelf.marker
                        self._infoWindow = this._____refToSelf.infoWindow
                    self._locations.push newMarker

            # Remove unseen items from list.
            tmp = []
            for i in self._locations
                if not i.notSeen
                    tmp.push i
                else
                    i.marker.setMap null    	
            self._locations = tmp
            
            if self._handlePossibleAdd
                self._handlePossibleAdd = false 
                found = false
                for i in self._locations
                    if i.marker.getPosition().lat() == self._place.geometry.location.lat() and i.marker.getPosition().lng() == self._place.geometry.location.lng()
                        i.infoWindow.open self._map, i.marker
                        found = true

                if not found
                    placeName = self._place.name
                    if self._place.formatted_address.indexOf(placeName) > -1
                        placeName = ""
                    view = 
                        id: 0
                        name: placeName
                        address: self._place.formatted_address
                        pin_enabled: false
                        contactless_enabled: false
                        edit_disabled: false
                    
                    contentString = Mustache.render(templates.per_item_entry, view)
        
                    if self._infoWindow?
                        self._infoWindow.close()
        
                    self._infoWindow = new google.maps.InfoWindow({
                        content: contentString,
                        position: self._place.geometry.location
                    })
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
                $("#emvBusinessInfo .add-toolbar").text("reported")
    
    getDrivingDirections: (addr) ->
        src = this._cur_lat + "," + this._cur_lon
        encoded_dest = encodeURI(addr)
        window.open "http://maps.apple.com/?daddr=" + encoded_dest + "&saddr=" + src
    
    addBusiness: () ->
        self = this;
        if $("#businessName").val() == ""
            alert "Name must be filled in before you can add this business to the map."
        else
            request = $.ajax "/businesses/add", {type: "POST", data: {
                name: $("#businessName").val(),
                address: $("#businessAddress").text(),
                latitude: this._place.geometry.location.lat(),
                longitude: this._place.geometry.location.lng(),
                pin_enabled: $("#pinEnabled").prop("checked"),
                contactless_enabled: $("#contactlessEnabled").prop("checked"),
            }}
            request.done (data) ->
                self._infoWindow.close()
        	
                view = 
                    id: data.id
                    name: data.name
                    address: data.address
                    pin_enabled: data.pin_enabled == "true"
                    contactless_enabled: data.contactless_enabled == "true"
                    edit_disabled: true
                
                windowContents = Mustache.render(templates.per_item_entry, view)
                                
                pinColor = "00FF00"
                    
                pinImage = new google.maps.MarkerImage("http://chart.apis.google.com/chart?chst=d_map_pin_letter&chld=%E2%80%A2|" + pinColor,
                    new google.maps.Size(21, 34),
                    new google.maps.Point(0,0),
                    new google.maps.Point(10, 34))
                pinShadow = new google.maps.MarkerImage("http://chart.apis.google.com/chart?chst=d_map_pin_shadow",
                    new google.maps.Size(40, 37),
                    new google.maps.Point(0, 0),
                    new google.maps.Point(12, 35))
                    
                newMarker = {
        	        marker: new google.maps.Marker({
        	            position: new google.maps.LatLng(data.lat, data.lng),
        	            map: self._map,
        	            icon: pinImage,
        	            shadow: pinShadow
        	        }),
        	        infoWindow: new google.maps.InfoWindow({
        	            content: windowContents
        	        })
                }
                google.maps.event.addListener newMarker.marker, "click", () ->
                    newMarker.infoWindow.open self._map, newMarker.marker
                self._locations.push newMarker
    
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
        
 
    @route "", () ->
        # Navigate to center of the US to start. Geolocation will move us to the correct location later.
        failFn = (errObj) ->
            window.app.navigate "/loc/39.828175/-98.579500", true, false
        failFn()

        self = this
        setTimeout(() ->
            if navigator.geolocation?
                successFn = (pos) ->
                    self._cur_lat = pos.coords.latitude
                    self._cur_lon = pos.coords.longitude
                    self._map.setZoom 8
                    window.app.navigate "/loc/" + pos.coords.latitude + "/" + pos.coords.longitude, true, false
                
                navigator.geolocation.getCurrentPosition successFn, () -> {}
        , 0)
        	
# initialize app
$(document).ready () ->
    window.app = new MainController
    window.app.start()
