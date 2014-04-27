class MainController extends SimpleMVC.Controller
    _navigateToNewBounds: () =>
        placeLoc = this._map.getCenter()
        window.app.navigate "/loc/" + placeLoc.lat() + "/" + placeLoc.lng(), true, false

    _navigateToAddress: () =>
        place = this._autocomplete.getPlace()
        placeLoc = place.geometry.location
        window.app.navigate "/loc/" + placeLoc.lat() + "/" + placeLoc.lng(), true, false
        this._place = place
        this._map.setZoom 15
        
        # TODO: wait for JSON result from server and then determine if our now current lat/long
        # contains an EMV enabled business. For now, assume we're creating a new one.
        # TODO 2: ick. We should be using SimpleMVC views to render the popup.
        contentString = '<div id="emvBusinessInfo">' +
            '<div class="add-name"><input type="text" id="businessName" placeholder="Name of the business" /></div>' +
            '<div class="add-address"><address id="businessAddress">' + place.formatted_address + '</address></div>' +
            '<div class="add-options"><input type="checkbox" id="pinEnabled" /><label for="pinEnabled">business has PIN pad</label></div>' +
            '<div class="add-toolbar"><a href="#" onclick="event.preventDefault(); window.app.addBusiness();">add business</a></div></div>'
        
        if this._infoWindow?
            this._infoWindow.close()
        
        this._infoWindow = new google.maps.InfoWindow({
            content: contentString,
            position: placeLoc
        })
        this._infoWindow.open this._map
    
    addBusiness: () ->
        request = $.ajax "/businesses/add", {type: "POST", data: {
        	name: $("#businessName").val(),
        	address: $("#businessAddress").text(),
        	latitude: this._place.geometry.location.lat(),
        	longitude: this._place.geometry.location.lng(),
        	pin_enabled: $("#pinEnabled").val()
        }}
        request.done (data) ->
            this._infoWindow.close
        	
            # TODO: ick. Use views for this.
            windowContents = '<div id="emvBusinessInfo">' +
                '<div class="add-name">' + data.name + '</div>' +
                '<div class="add-address"><address>' + data.address + '</address></div>' +
                '<div class="add-options"><input type="checkbox" id="pinEnabled" value="' + data.pin_enabled + '" disabled /><label for="pinEnabled">business has PIN pad</label></div>' +
                '<div class="add-toolbar"><a href="#">report errors</a></div></div>'
                
            self._locations.push {
        	    marker: new google.maps.Marker({
        	        position: new google.maps.LatLng(data.lat, data.lng),
        	        map: self._map
        	    }),
        	    infoWindow: new google.maps.InfoWindow({
        	        content: windowContents
        	    })
            }
    
    @route "loc/:lat/:long", (lat, lng) ->
        mapOptions = {
            zoom: 8,
            center: new google.maps.LatLng(lat, lng),
            noClear: true
        }
        if not this._map?
            this._map = new google.maps.Map(document.getElementById("map-canvas"), mapOptions)
        	
        	# handler so we can reload the list
            google.maps.event.addListener this._map, "bounds_changed", this._navigateToNewBounds
        	
            # initialize autocomplete widget
            this._autocomplete = new google.maps.places.Autocomplete(document.getElementById("address"))
            google.maps.event.addListener this._autocomplete, 'place_changed', this._navigateToAddress
        else
            this._map.panTo mapOptions.center
        
        # Clear existing markers and info windows if needed.
        if this._locations?
            for i in this._locations
                i.marker.setMap null
            this._locations.length = 0
        else
            this._locations = []
        
        mapBounds = this._map.getBounds()
        mapNE = mapBounds.getNorthEast()
        mapSW = mapBounds.getSouthWest()
        
        query = $.ajax "/businesses/" + mapNE.lat() + "/" + mapNE.lng() + "/" + mapSW.lat() + "/" + mapSW.lng()
        self = this
        query.done (data) ->
            for i in data
                # TODO: ick. Use views for this.
                windowContents = '<div id="emvBusinessInfo">' +
                    '<div class="add-name">' + i.name + '</div>' +
                    '<div class="add-address"><address>' + i.address + '</address></div>' +
                    '<div class="add-options"><input type="checkbox" id="pinEnabled" value="' + i.pin_enabled + '" disabled /><label for="pinEnabled">business has PIN pad</label></div>' +
                    '<div class="add-toolbar"><a href="#">report errors</a></div></div>'
                    
                self._locations.push {
            	    marker: new google.maps.Marker({
            	        position: new google.maps.LatLng(i.lat, i.lng),
            	        map: self._map
            	    }),
            	    infoWindow: new google.maps.InfoWindow({
            	        content: windowContents
            	    })
                }
    
    @route "", () ->
        failFn = (errObj) ->
            # Exact center of the continental US
            window.app.navigate "/loc/39.828175/-98.579500", true, false
            
        if navigator.geolocation?
            successFn = (pos) ->
                window.app.navigate "/loc/" + pos.coords.latitude + "/" + pos.coords.longitude, true, false
                
            navigator.geolocation.getCurrentPosition successFn, failFn
        else
        	failFn()
        	
# initialize app
$(document).ready () ->
    window.app = new MainController
    window.app.start()