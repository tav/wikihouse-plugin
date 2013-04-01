  
module WikihouseExtension   

   # ------------------------------------------------------------------------------
   # DXF Writer
   # ------------------------------------------------------------------------------
   
   class WikiHouseDXF
   
     def initialize(layout)
     end
   
     def generate
       ""
     end
   
   end
   
   # ------------------------------------------------------------------------------
   # SVG Writer
   # ------------------------------------------------------------------------------
   
  class WikiHouseSVG
  
    def initialize(layout, scale)
      @layout = layout
      @scale = scale
    end
  
    def generate
  
      layout = @layout
      scale = @scale
  
      sheet_height, sheet_width, inner_height, inner_width, margin = layout.dimensions
      sheets = layout.sheets
      count = sheets.length
  
      scaled_height = scale * sheet_height
      scaled_width = scale * sheet_width
      total_height = scale * ((count * (sheet_height + (12 * margin))) + (margin * 10))
      total_width = scale * (sheet_width + (margin * 2))
  
      svg = []
      svg << <<-HEADER.gsub(/^ {6}/, '')
        <?xml version="1.0" standalone="no"?>
        <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
        <svg height="#{total_height}" version="1.1"
             viewBox="0 0 #{total_width} #{total_height}" xmlns="http://www.w3.org/2000/svg"
             xmlns:xlink="http://www.w3.org/1999/xlink" style="background-color: #ffffff;">
        <desc>#{WIKIHOUSE_TITLE} Cutting Sheets</desc>"
        <!-- linkstart -->
        <g visibility="hidden" pointer-events="all">
          <rect x="0" y="0" width="100%" height="100%" fill="none" />
        </g>
        HEADER
  
      loop_count = 0
  
      for s in 0...count
  
        sheet = sheets[s]
        base_x = scale * margin
        base_y = scale * ((s * (sheet_height + (12 * margin))) + (margin * 9))
  
        svg << "<rect x=\"#{base_x}\" y=\"#{base_y}\" width=\"#{scaled_width}\" height=\"#{scaled_height}\" fill=\"none\" stroke=\"rgb(210, 210, 210)\" stroke-width=\"1\" />"
  
        base_x += scale * margin
        base_y += scale * margin
  
        sheet.each do |loops, circles, outer_mapped, centroid, label|
  
          Sketchup.set_status_text WIKIHOUSE_SVG_STATUS[(loop_count/5) % 5]
          loop_count += 1
  
          svg << '<g fill="none" stroke="rgb(255, 255, 255)" stroke-width="1">'
  
          for i in 0...loops.length
            circle = circles[i]
            if circle
              center, radius = circle
              x = (scale * center.x) + base_x
              y = (scale * center.y) + base_y
              radius = scale * radius
              svg << <<-CIRCLE.gsub(/^ {14}/, '')
                <circle cx="#{x}" cy="#{y}" r="#{radius}"
                        stroke="rgb(51, 51, 51)" stroke-width="2" fill="none" />
                CIRCLE
            else
              loop = loops[i]
              first = loop.shift
              path = []
              path << "M #{(scale * first.x) + base_x} #{(scale * first.y) + base_y}"
              loop.each do |point|
                path << "L #{(scale * point.x) + base_x} #{(scale * point.y) + base_y}"
              end
              path << "Z"
              svg << <<-PATH.gsub(/^ {14}/, '')
                <path d="#{path.join ' '}" stroke="rgb(0, 0, 0)" stroke-width="2" fill="none" />
                PATH
            end
          end
  
          if label and label != ""
            svg << <<-LABEL.gsub(/^ {12}/, '')
              <text x="#{(scale * centroid.x) + base_x}" y="#{(scale * centroid.y) + base_y}" style="font-size: 5mm; stroke: rgb(255, 0, 0); fill: rgb(255, 0, 0); text-family: monospace">#{label}</text>
              LABEL
          end
  
          svg << '</g>'
  
        end
      end
  
      svg << '<!-- linkend -->'
      svg << '</svg>'
      svg.join "\n"
  
    end
  
  end

end