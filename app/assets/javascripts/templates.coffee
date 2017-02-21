if not @templates?
    templates = exports? and exports or @templates = {}
else
    templates = @templates

Handlebars.registerHelper 'moreThanZero', (item, options) -> 
	if Object.keys(item).length > 0
		return options.fn(item)
	else
		return ""

Handlebars.registerHelper 'getSingleItem', (item, options) -> 
	result = null
	for k, v of item.businesses
		if not result
			result = v
	return options.fn(result)
	
templates.per_item_entry = """
{{^edit_disabled}}
{{#getSingleItem this}}
<div id="emvBusinessInfo">
  <div class="add-name">
      <input type="text" id="businessName" value="{{name}}" placeholder="Name of the business" />
  </div>
  <div class="add-address" id="businessAddress"><address>{{address}}</address></div>
  <div class="add-options">
    <input type="checkbox" id="pinEnabled" value="true" />
    <label for="pinEnabled">business has PIN pad (<a href="/itemlegend#pin" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="contactlessEnabled" value="true" />
    <label for="contactlessEnabled">business supports Apple/Android Pay (<a href="/itemlegend#contactless" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="unattendedTerminals" value="true" />
    <label for="unattendedTerminals">has unattended terminals (<a href="/itemlegend#unattended" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="gasPumpWorking" value="true" />
    <label for="gasPumpWorking">works at pump (gas station only) (<a href="/itemlegend#gas" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="payAtTable" value="true" />
    <label for="payAtTable">has pay at the table (restaurants only) (<a href="/itemlegend#payattable" target="_blank">explain</a>)</label>
  </div>
  <div class="add-toolbar">
    <a href="#" onclick="event.preventDefault(); window.app.addBusiness();">add business</a>
  </div>
</div>
{{/getSingleItem}}
{{/edit_disabled}}
{{#edit_disabled}}
{{#if onlyOneBusiness}}
{{#getSingleItem this}}
<div id="emvBusinessInfo">
  <div class="add-name">
      <input type="text" id="businessName" value="{{name}}" disabled placeholder="Name of the business" />
  </div>
  <div class="add-address" id="businessAddress"><address>{{address}}</address></div>
  <div class="add-options">
    <input type="checkbox" id="pinEnabled" disabled value="true" {{#if pin_enabled}}checked{{/if}}/>
    <label for="pinEnabled">business has PIN pad (<a href="/itemlegend#pin" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="contactlessEnabled" disabled {{#if contactless_enabled}}checked{{/if}} value="true" />
    <label for="contactlessEnabled">business supports Apple/Android Pay (<a href="/itemlegend#contactless" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="unattendedTerminals" disabled {{#if unattended_terminals}}checked{{/if}} value="true" />
    <label for="unattendedTerminals">has unattended terminals (<a href="/itemlegend#unattended" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="gasPumpWorking" disabled {{#if gas_pump_working}}checked{{/if}} value="true" />
    <label for="gasPumpWorking">works at pump (gas station only) (<a href="/itemlegend#gas" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="payAtTable" disabled {{#if pay_at_table}}checked{{/if}} value="true" />
    <label for="payAtTable">has pay at the table (restaurants only) (<a href="/itemlegend#payattable" target="_blank">explain</a>)</label>
  </div>
  <div class="add-toolbar">
    <a id="addBusinessLink" style="display: none;" href="#" onclick="event.preventDefault(); window.app.addBusiness();">add business</a>
    <span id="addNewBusinessLink"><a href="#" onclick="event.preventDefault(); window.app.addNewBusiness('{{id}}');">add additional business</a> | </span>
    <span id="getDirectionsLink"><a href="#" onclick="event.preventDefault(); window.app.getDrivingDirections('{{address}}');">get directions</a> | </span>
    <span id="report-errors-{{id}}"><a href="#" onclick="event.preventDefault(); window.app.reportError('{{id}}');">report errors</a></span>
  </div>
</div>
{{/getSingleItem}}
{{/if}}
{{^if onlyOneBusiness}}
<div id="emvBusinessInfo">
  <div class="add-name">
      <input type="text" id="businessName" value="{{foundPlaceName}}" placeholder="Name of the business" />
  </div>
  {{#getSingleItem this}}
  <div class="add-address" id="businessAddress"><address>{{address}}</address></div>
  <div class="add-options">
    <input type="checkbox" id="pinEnabled" value="true" />
    <label for="pinEnabled">business has PIN pad (<a href="/itemlegend#pin" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="contactlessEnabled" value="true" />
    <label for="contactlessEnabled">business supports Apple/Android Pay (<a href="/itemlegend#contactless" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="unattendedTerminals" value="true" />
    <label for="unattendedTerminals">has unattended terminals (<a href="/itemlegend#unattended" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="gasPumpWorking" value="true" />
    <label for="gasPumpWorking">works at pump (gas station only) (<a href="/itemlegend#gas" target="_blank">explain</a>)</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="payAtTable" value="true" />
    <label for="payAtTable">has pay at the table (restaurants only) (<a href="/itemlegend#payattable" target="_blank">explain</a>)</label>
  </div>
  <div class="add-toolbar">
    <a href="#" onclick="event.preventDefault(); window.app.addBusiness();">add business</a> | <a href="#" onclick="event.preventDefault(); window.app.getDrivingDirections('{{address}}');">get directions</a>
  </div>
  {{/getSingleItem}}
</div>
{{#moreThanZero businesses}}
<h4>More than one business at this address</h4>
<div class="emvBusinessList">
{{#each this}}
<div class="slimEmvBusinessInfo">
  	{{name}}: 
  	  <input type="checkbox" value="true" {{#pin_enabled}}checked{{/pin_enabled}} disabled /> PIN
      <input type="checkbox" value="true" {{#contactless_enabled}}checked{{/contactless_enabled}} disabled /> NFC
      <input type="checkbox" value="true" {{#unattended_terminals}}checked{{/unattended_terminals}} disabled /> Unattended terminals
	  <input type="checkbox" value="true" {{#gas_pump_working}}checked{{/gas_pump_working}} disabled /> Gas pump
      <input type="checkbox" value="true" {{#pay_at_table}}checked{{/pay_at_table}} disabled /> Pay at table
      <input type="checkbox" value="true" {{#confirmed_location}}checked{{/confirmed_location}} disabled /> Confirmed
    (<span id="report-errors-{{id}}"><a href="#" onclick="event.preventDefault(); window.app.reportError('{{id}}');">report errors</a></span>)
</div>
{{/each}}
</div>
{{/moreThanZero}}
{{/if}}
{{/edit_disabled}}
"""

templates.per_item_entry = Handlebars.compile(templates.per_item_entry)