# ------------------------------------------------------------------------------
# Wikihouse Constants
# ------------------------------------------------------------------------------

module WikihouseExtension
  
  # Pannel stuff
  PANEL_ID_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  PANEL_ID_ALPHABET_LENGTH = PANEL_ID_ALPHABET.length

  WIKIHOUSE_FONT_HEIGHT = 30.mm
  WIKIHOUSE_PANEL_PADDING = 25.mm / 2
  WIKIHOUSE_SHEET_HEIGHT = 1200.mm
  WIKIHOUSE_SHEET_MARGIN = 15.mm - WIKIHOUSE_PANEL_PADDING
  WIKIHOUSE_SHEET_WIDTH = 2400.mm
  
  
  # Set Wikihouse Pannel Dimentions
  WIKIHOUSE_SHEET_INNER_HEIGHT = WIKIHOUSE_SHEET_HEIGHT - (2 * WIKIHOUSE_SHEET_MARGIN)
  WIKIHOUSE_SHEET_INNER_WIDTH = WIKIHOUSE_SHEET_WIDTH - (2 * WIKIHOUSE_SHEET_MARGIN)
  
  WIKIHOUSE_DIMENSIONS = [
    WIKIHOUSE_SHEET_HEIGHT,
    WIKIHOUSE_SHEET_WIDTH,
    WIKIHOUSE_SHEET_INNER_HEIGHT,
    WIKIHOUSE_SHEET_INNER_WIDTH,
    WIKIHOUSE_SHEET_MARGIN,
    WIKIHOUSE_PANEL_PADDING,
    WIKIHOUSE_FONT_HEIGHT
    ]
  
  # Status Messages 
  WIKIHOUSE_DETECTION_STATUS = gen_status_msg "Detecting matching faces"
  WIKIHOUSE_DXF_STATUS = gen_status_msg "Generating DXF output"
  WIKIHOUSE_LAYOUT_STATUS = gen_status_msg "Nesting panels for layout"
  WIKIHOUSE_PANEL_STATUS = gen_status_msg "Generating panel data"
  WIKIHOUSE_SVG_STATUS = gen_status_msg "Generating SVG output"
      
  # UI Message Box codes 
  REPLY_ABORT = 3
  REPLY_CANCEL = 2
  REPLY_NO = 7
  REPLY_OK = 1
  REPLY_RETRY = 4
  REPLY_YES = 6
  
  # Dummy Group
  class WikiHouseDummyGroup 
    attr_reader :name
  
    def initialize
      @name = "Ungrouped Objects"
    end
  end
  WIKIHOUSE_DUMMY_GROUP = WikiHouseDummyGroup.new

end
