/* Dialog namespace */
var Dialog = function() {
  return {
  
    init : function() {
      Dialog.setup_events();
    },
    
    // Ensure links are opened in the default browser.
    setup_events : function() {
      // Import
      $('#btnAccept').on('click', function(event) {
        window.location = 'skp:Event_Accept';
      });
      // Cancel
      $('#btnCancel').on('click', function(event) {
        window.location = 'skp:Event_Cancel';
      });
    }
    
  };
  
}(); // Dialog

$(document).ready( Dialog.init );