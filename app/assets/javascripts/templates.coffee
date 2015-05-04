if not @templates?
    templates = exports? and exports or @templates = {}
else
    templates = @templates
    
templates.per_item_entry = """
<div id="emvBusinessInfo">
  <div class="add-name">
      {{^edit_disabled}}
      <input type="text" id="businessName" value="{{name}}" placeholder="Name of the business" />
      {{/edit_disabled}}
      {{#edit_disabled}}
      {{name}}
      {{/edit_disabled}}
  </div>
  <div class="add-address" id="businessAddress"><address>{{address}}</address></div>
  <div class="add-options">
    <input type="checkbox" id="pinEnabled" value="true" {{#pin_enabled}}checked{{/pin_enabled}} {{#edit_disabled}}disabled{{/edit_disabled}} />
    <label for="pinEnabled">business has PIN pad</label>
  </div>
  <div class="add-options">
    <input type="checkbox" id="contactlessEnabled" value="true" {{#contactless_enabled}}checked{{/contactless_enabled}} {{#edit_disabled}}disabled{{/edit_disabled}} />
    <label for="contactlessEnabled">business supports contactless cards</label>
  </div>
  <div class="add-toolbar">
    {{#edit_disabled}}
    <a href="#" onclick="event.preventDefault(); window.app.reportError(' + {{id}} + ');">
      report errors
    </a>
    {{/edit_disabled}}
    {{^edit_disabled}}
    <a href="#" onclick="event.preventDefault(); window.app.addBusiness();">add business</a>
    {{/edit_disabled}}
  </div>
</div>
"""