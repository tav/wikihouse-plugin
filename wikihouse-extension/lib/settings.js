// JavaScript File for settings.html 
// @author: C. Musselle 

// Debugging
window.onerror = function (msg, url, line) {
   alert("Message : " + msg + "\n\nurl : " + url + "\n\nLine No: " + line);
}

window.onload = function() { fetch_settings('current') }
// For some reason the page is loaded blank untill the window is refocused onto.
window.blur()
window.focus()

// Define Globals
var settings;

// Parse Wikihouse Settings for the input JSON string  
function recieve_wikihouse_settings(args) {
	
	  /*
	  @@wikihouse_settings = {
	  "sheet_height"        => wikihouse_sheet_height,
	  "sheet_inner_height"  => wikihouse_sheet_inner_height,
	  "sheet_width"         => wikihouse_sheet_width, 
	  "sheet_inner_width"   => wikihouse_sheet_inner_width, 
	  "padding"             => wihihouse_panel_padding,
	  "margin"              => wikihouse_sheet_margin,
	  "font_height"         => wikihouse_font_height,
	  }
	  */

	  settings = JSON.parse(args)
	  
	  document.getElementById("sheet_height").value = settings.sheet_height;
	  document.getElementById("sheet_width").value = settings.sheet_width;
	  document.getElementById("margin").value = settings.margin;
	  document.getElementById("padding").value = settings.padding;
	  document.getElementById("font_height").value = settings.font_height;
	}

// Update Settings 
function send_wikihouse_settings(mode) {
  
	
  var fields = new Array("sheet_height", "sheet_width", "margin",
    "padding", "font_height");
  
  var idx, value, args;  

  for (idx in fields) {
	  
	  value = eval(document.getElementById(fields[idx]).value)
	  
	  if (typeof value == "number") {
		  // Only update those that are genuine numbers
		  settings[fields[idx]] = value
	  }
  }


  //Convert to String  
  args = JSON.stringify(settings)
  
  // Possibly add close flag for dialogue 
  if (mode == 1) {
    args = args + "--close";
  }
  
  //Send argument to SketchUp script for processing
  window.location.href = "skp:update_settings@" + args;
}

function cancel() {
  window.location.href = 'skp:cancel_settings@';
}

function display_status(msg) {
  document.getElementById("status_out").innerHTML = msg;
}

function fetch_settings(arg) {
  window.location.href = 'skp:fetch_settings@' + arg;
}

// For debugging
function do_stuff() {
	alert(typeof settings.padding)
//	alert(settings["sheet_height"] = eval('12'))
//	alert(settings["sheet_height"] = eval(234566))
}






