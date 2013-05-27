# Public Domain (-) 2011 The WikiHouse Authors.
# See the WikiHouse UNLICENSE file for details.

# =========================
# WikiHouse SketchUp Plugin
# =========================

require 'sketchup.rb'

# ------------------
# Update Path Arrays
# ------------------

# Using regular require statments don't seem to work with the embedded Ruby in SketchUp
# unless the full path of files is included in the $LOAD_PATH array 

# Add current working directory to $LOAD_PATH array 
cwd = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift(cwd) unless $LOAD_PATH.include?(cwd)

# Add all files in the lib directory to the $LOAD_PATH array
abs_lib_path = File.join(File.expand_path(File.dirname(__FILE__)), "lib")
$LOAD_PATH.unshift(abs_lib_path) unless $LOAD_PATH.include?(abs_lib_path)
require_all(abs_lib_path)


module WikihouseExtension # Top Level Namespace
  
  module_function() # Makes all methods defined in the module callable via
  #ModuleName.method. Else would have to define a class and mix them into it first.

  # ------------------------------------------------------------------------------
  # Layout Engine
  # ------------------------------------------------------------------------------
  class WikiHouseLayoutEngine
    
    attr_accessor :sheets
    attr_reader :dimensions
  
    def initialize(panels, root, dimensions)
  
      @dimensions = dimensions
      @sheets = sheets = []
  
      # Set local variables to save repeated lookups.
      sheet_height, sheet_width, inner_height, inner_width,
      sheet_margin, panel_padding, font_height = dimensions
  
      # Filter out the singletons from the other panels.
      singletons = panels.select { |panel| panel.singleton }
      panels = panels.select { |panel| !panel.singleton }
  
      # Loop through the panels.
      panels.map! do |panel|
  
        # Get padding related info.
        no_padding = panel.no_padding
  
        # Get the bounding box.
        min = panel.min
        max = panel.max
        min_x, min_y = min.x, min.y
        max_x, max_y = max.x, max.y
  
        # Set a flag to indicate clipped panels.
        clipped = false
  
        # Determine if the potential savings exceeds the hard-coded threshold. If
        # so, see if we can generate an outline with rectangular areas clipped
        # from each corner.
        if (panel.bounds_area - panel.shell_area) > 50
          # puts (panel.bounds_area - panel.shell_area)
        end
  
        # Otherwise, treat the bounding box as the outline.
        if not clipped
  
          # Define the inner outline.
          inner = [[min_x, min_y, 0], [max_x, min_y, 0], [max_x, max_y, 0], [min_x, max_y, 0]]
  
          # Add padding around each side.
          if not no_padding
            min_x -= panel_padding
            min_y -= panel_padding
            max_x += panel_padding
            max_y += panel_padding
          elsif no_padding == "w"
            min_y -= panel_padding
            max_y += panel_padding
          elsif no_padding == "h"
            min_x -= panel_padding
            max_x += panel_padding
          end
  
          # Calculate the surface area that will be occupied by this panel.
          width = max_x - min_x
          height = max_y - min_y
          area = width * height
  
          # Define the padded outer outline.
          # outline = [[min_x, max_y, 0], [max_x, max_y, 0], [max_x, min_y, 0], [min_x, min_y, 0]]
          outer = [[min_x, min_y, 0], [max_x, min_y, 0], [max_x, max_y, 0], [min_x, max_y, 0]]
          outlines = [[nil, inner, outer]]
  
          # See if the panel can be rotated, if so add the transformation.
          if not no_padding
            if (inner_width > height) and (inner_height > width)
              # inner = [inner[3], inner[0], inner[1], inner[2]]
              # outer = [outer[3], outer[0], outer[1], outer[2]]
              outlines << [90.degrees, inner, outer]
              outlines << [270.degrees, inner, outer]
            end
            outlines << [180.degrees, inner, outer]
          end
  
        end
  
        # Save the generated data.
        [panel, outlines, area, panel.labels.dup]
  
      end
  
      # Sort the panels by surface area.
      panels = panels.sort_by { |data| data[2] }.reverse
  
      # Generate new groups to hold sheet faces.
      inner_group = root.add_group
      inner_faces = inner_group.entities
      outer_group = root.add_group
      outer_faces = outer_group.entities
      temp_group = root.add_group
      temp_faces = temp_group.entities
      total_area = inner_width * inner_height
  
      # Initialise the loop counter.
      loop_count = 0
  
      # Make local certain global constants.
      outside = Sketchup::Face::PointOutside
  
      # panels = panels[-10...-1]
      # panels = panels[-5...-1]
      c = 0
  
      # Do the optimising layout.
      while 1
  
        # Create a fresh sheet.
        sheet = []
        available_area = total_area
        idx = 0
        placed_i = []
        placed_o = []
  
        while available_area > 0
  
          Sketchup.set_status_text WIKIHOUSE_LAYOUT_STATUS[(loop_count/20) % 5]
          loop_count += 1
  
          panel_data = panels[idx]
          
          if not panel_data
            break
          end
  
          panel, outlines, panel_area, labels = panel_data
          if panel_area > available_area
            idx += 1
            next
          end
  
          match = true
          t = nil
          used = nil
  
          # If this is the first item, do the cheap placement check.
          if sheet.length == 0
            transform, inner, outer = outlines[0]
            point = outer[0]
            translate = Geom::Transformation.translation [-point[0], -point[1], 0]
            inner.each do |point|
              point = translate * point
              if (point.x > inner_width) or (-point.y > inner_height)
                p (point.x - inner_width)
                p (point.y - inner_height)
                match = false
                break
              end
            end
            if not match
              puts "Error: couldn't place panel onto an empty sheet"
              panels.delete_at idx
              next
            end
            t = translate
            used = [inner, outer]
          else
            # Otherwise, loop around the already placed panel regions and see if
            # the outline can be placed next to it.
            match = false
            placed_o.each do |face|
              # Loop through the vertices of the available region.
              face.outer_loop.vertices.each do |vertex|
                origin = vertex.position
                # Loop through each outline.
                outlines.each do |angle, inner, outer|
                  # Loop through every vertex of the outline, starting from the
                  # top left.
                  p_idx = -1
                  all_match = true
                  while 1
                    p0 = outer[p_idx]
                    if not p0
                      break
                    end
                    transform = Geom::Transformation.translation([origin.x - p0[0], origin.y - p0[1], 0])
                    if angle
                      transform = transform * Geom::Transformation.rotation(origin, Z_AXIS, angle)
                    end
                    # Check every point to see if it's within the available region.
                    all_match = true
                    inner.each do |point|
                      point = transform * point
                      px, py = point.x, point.y
                      if (px < 0) or (py < 0) or (px > inner_width) or (py > inner_height)
                        all_match = false
                        break
                      end
                      placed_o.each do |placement|
                        if placement.classify_point(point) != outside
                          all_match = false
                          break
                        end
                      end
                      if not all_match
                        break
                      end
                    end
                    # If the vertices don't overlap, check that the edges don't
                    # intersect.
                    if all_match
                      # TODO(tav): Optimise with a sweep line algorithm variant:
                      # http://en.wikipedia.org/wiki/Sweep_line_algorithm
                      outer_mapped = outer.map { |point| transform * point }
                      for i in 0...outer.length
                        p1 = outer_mapped[i]
                        p2 = outer_mapped[i+1]
                        if not p2
                          p2 = outer_mapped[0]
                        end
                        p1x, p1y = p1.x, p1.y
                        p2x, p2y = p2.x, p2.y
                        s1 = p2x - p1x
                        s2 = p2y - p1y
                        edge = [p1, [s1, s2, 0]]
                        edge_length = Math.sqrt((s1 * s1) + (s2 * s2))
                        placed_i.each do |placement|
                          placement.edges.each do |other_edge|
                            intersection = Geom.intersect_line_line edge, other_edge.line
                            if intersection
                              p3x, p3y = intersection.x, intersection.y
                              s1 = p3x - p1x
                              s2 = p3y - p1y
                              length = Math.sqrt((s1 * s1) + (s2 * s2))
                              if length > edge_length
                                next
                              end
                              s1 = p3x - p2x
                              s2 = p3y - p2y
                              length = Math.sqrt((s1 * s1) + (s2 * s2))
                              if length > edge_length
                                next
                              end
                              other_edge_length = other_edge.length
                              p4, p5 = other_edge.start.position, other_edge.end.position
                              s1 = p3x - p4.x
                              s2 = p3y - p4.y
                              length = Math.sqrt((s1 * s1) + (s2 * s2))
                              if length > other_edge_length
                                next
                              end
                              s1 = p3x - p5.x
                              s2 = p3y - p5.y
                              length = Math.sqrt((s1 * s1) + (s2 * s2))
                              if length > other_edge_length
                                next
                              end
                              all_match = false
                              break
                            end
                          end
                          if not all_match
                            break
                          end
                        end
                        if not all_match
                          break
                        end
                      end
                    end
                    if all_match
                      match = true
                      t = transform
                      used = [inner, outer]
                    end
                    p_idx -= 1
                    if match
                      break
                    end
                  end
                  if match
                    break
                  end
                end
                if match
                  break
                end
              end
              if match
                break
              end
            end
          end
  
          if match
  
            available_area -= panel_area
            inner_faces.add_face(used[0].map { |p| t * p })
            outer_faces.add_face(used[1].map { |p| t * p })
            placed_i = inner_faces.select { |e| e.typename == "Face" }
            placed_o = outer_faces.select { |e| e.typename == "Face" }
  
            # Generate the new loop vertices.
            loops = panel.loops.map do |loop|
              loop.map do |point|
                t * point
              end
            end
  
            # Generate the new circle data.
            circles = panel.circles.map do |circle|
              if circle
                center = t * circle[0]
                [center, circle[1]]
              else
                nil
              end
            end
  
            # Generate the new centroid.
            centroid = t * panel.centroid
  
            # Get the label.
            label = labels.pop
  
            # If this was the last label, remove the panel.
            if labels.length == 0
              panels.delete_at idx
            end
  
            outer_mapped = outer.map { |p| t * p }
  
            # Append the generated data to the current sheet.
            sheet << [loops, circles, outer_mapped, centroid, label]
            c += 1
  
          else
  
            # We do not have a match, try the next panel.
            idx += 1
  
          end
  
        end
  
        # If no panels could be fitted, break so as to avoid an infinite loop.
        if sheet.length == 0
          break
        end
  
        # Add the sheet to the collection.
        sheets << sheet
  
        # If there are no more panels remaining, exit the loop.
        if panels.length == 0
          break
        end
  
        # Wipe the generated entities.
        inner_faces.clear!
        outer_faces.clear!
  
      end
  
      # Delete the generated sheet group.
      root.erase_entities [inner_group, outer_group]
  
    end
  
  end
  
  # ------------------------------------------------------------------------------
  # Panel
  # ------------------------------------------------------------------------------
  
  class WikiHousePanel
  
    attr_accessor :area, :centroid, :circles, :labels, :loops, :max, :min
    attr_reader :bounds_area, :error, :no_padding, :shell_area, :singleton
  
    def initialize(root, face, transform, labels, limits)
  
      # Initalise some of the object attributes.
      @error = nil
      @labels = labels
      @no_padding = false
      @singleton = false
  
      # Initialise a variable to hold temporarily generated entities.
      to_delete = []
  
      # Create a new face with the vertices transformed if the transformed areas
      # do not match.
      if (face.area - face.area(transform)).abs > 0.1
        group_entity = root.add_group
        to_delete << group_entity
        group = group_entity.entities
        tface = group.add_face(face.outer_loop.vertices.map {|v| transform * v.position })
        face.loops.each do |loop|
          if not loop.outer?
            hole = group.add_face(loop.vertices.map {|v| transform * v.position })
            hole.erase! if hole.valid?
          end
        end
        face = tface
      end
  
      # Save the total surface area of the face.
      total_area = face.area
  
      # Find the normal to the face.
      normal = face.normal
      y_axis = normal.axes[1]
  
      # See if the face is parallel to any of the base axes.
      if normal.parallel? X_AXIS
        x, y = 1, 2
      elsif normal.parallel? Y_AXIS
        x, y = 0, 2
      elsif normal.parallel? Z_AXIS
        x, y = 0, 1
      else
        x, y = nil, nil
      end
  
      # Initialise the ``loops`` variable.
      loops = []
  
      # Initialise a reference point for transforming slanted faces.
      base = face.outer_loop.vertices[0].position
  
      # Loop through the edges and convert the face into a 2D polygon -- ensuring
      # that we are traversing the edges in the right order.
      face.loops.each do |loop|
        newloop = []
        if loop.outer?
          loops.insert 0, newloop
        else
          loops << newloop
        end
        edgeuse = first = loop.edgeuses[0]
        virgin = true
        prev = nil
        while 1
          edge = edgeuse.edge
          if virgin
            start = edge.start
            stop = edge.end
            next_edge = edgeuse.next.edge
            next_start = next_edge.start
            next_stop = next_edge.end
            if (start == next_start) or (start == next_stop)
              stop, start = start, stop
            elsif not ((stop == next_start) or (stop == next_stop))
              @error = "Unexpected edge connection"
              return
            end
            virgin = nil
          else
            start = edge.start
            stop = edge.end
            if stop == prev
              stop, start = start, stop
            elsif not start == prev
              @error = "Unexpected edge connection"
              return
            end
          end
          if x
            # If the face is parallel to a base axis, use the cheap conversion
            # route.
            point = start.position.to_a
            newloop << [point[x], point[y], 0]
          else
            # Otherwise, handle the case where the face is angled at a slope by
            # realigning edges relative to the origin and rotating them according
            # to their angle to the y-axis.
            point = start.position
            edge = Geom::Vector3d.new(point.x - base.x, point.y - base.y, point.z - base.z)
            if not edge.valid?
              newloop << [base.x, base.y, 0]
            else
              if edge.samedirection? y_axis
                angle = 0
              elsif edge.parallel? y_axis
                angle = Math::PI
              else
                angle = edge.angle_between y_axis
                if not edge.cross(y_axis).samedirection? normal
                  angle = -angle
                end
              end
              rotate = Geom::Transformation.rotation ORIGIN, Z_AXIS, angle
              newedge = rotate * Geom::Vector3d.new(edge.length, 0, 0)
              newloop << [base.x + newedge.x, base.y + newedge.y, 0]
            end
          end
          edgeuse = edgeuse.next
          if edgeuse == first
            break
          end
          prev = stop
        end
      end
  
      # Initialise some more meta variables.
      areas = []
      circles = []
      cxs, cys = [], []
      intersections = []
      outer_loop = true
  
      # Go through the various loops calculating centroids, face area, and intersection points
      # of potential curves.
      loops.each do |loop|
        idx = 0
        intersect_points = []
        area = 0
        cx, cy = 0, 0
        while 1
          # Get the next three points on the loop.
          p1, p2, p3 = loop[idx...idx+3]
          if not p3
            if not p1
              break
            end
            if not p2
              # Loop around to the first edge.
              p2 = loop[0]
              p3 = loop[1]
            else
              # Loop around to the first point.
              p3 = loop[0]
            end
          end
          # Construct the edge vectors.
          edge1 = Geom::Vector3d.new(p2.x - p1.x, p2.y - p1.y, p2.z - p1.z)
          edge2 = Geom::Vector3d.new(p3.x - p2.x, p3.y - p2.y, p3.z - p2.z)
          intersect = nil
          if not edge1.parallel? edge2
            # Find the perpendicular vectors.
            cross = edge1.cross edge2
            vec1 = edge1.cross cross
            vec2 = edge2.cross cross
            # Find the midpoints.
            mid1 = Geom.linear_combination 0.5, p1, 0.5, p2
            mid2 = Geom.linear_combination 0.5, p2, 0.5, p3
            # Try finding an intersection.
            line1 = [mid1, vec1]
            line2 = [mid2, vec2]
            intersect = Geom.intersect_line_line line1, line2
            # If no intersection, try finding one in the other direction.
            if not intersect
              vec1.reverse!
              vec2.reverse!
              intersect = Geom.intersect_line_line line1, line2
            end
          end
          intersect_points << intersect
          if p3
            x1, y1 = p1.x, p1.y
            x2, y2 = p2.x, p2.y
            cross = (x1 * y2) - (x2 * y1)
            area += cross
            cx += (x1 + x2) * cross
            cy += (y1 + y2) * cross
          end
          idx += 1
        end
        intersections << intersect_points
        area = area * 0.5
        areas << area.abs
        cxs << (cx / (6 * area))
        cys << (cy / (6 * area))
        outer_loop = false
      end
  
      # Allocate variables relating to the minimal alignment.
      bounds_area = nil
      bounds_min = nil
      bounds_max = nil
      transform = nil
      outer = loops[0]
  
      # Unpack panel dimension limits.
      panel_height, panel_width, panel_max_height, panel_max_width, padding = limits
  
      # Try rotating at half degree intervals and find the transformation which
      # occupies the most minimal bounding rectangle.
      (0...180.0).step(0.5) do |angle|
        t = Geom::Transformation.rotation ORIGIN, Z_AXIS, angle.degrees
        bounds = Geom::BoundingBox.new
        outer.each do |point|
          point = t * point
          bounds.add point
        end
        min, max = bounds.min, bounds.max
        height = max.y - min.y
        width = max.x - min.x
        if (height - panel_height) > 0.1
          next
        end
        if (width - panel_width) > 0.1
          next
        end
        area = width * height
        if (not bounds_area) or ((bounds_area - area) > 0.1)
          bounds_area = area
          bounds_min, bounds_max = min, max
          transform = t
        end
      end
      
      # If we couldn't find a fitting angle, try again at 0.1 degree intervals.
      if not transform
        (0...180.0).step(0.1) do |angle|
          t = Geom::Transformation.rotation ORIGIN, Z_AXIS, angle.degrees
          bounds = Geom::BoundingBox.new
          outer.each do |point|
            point = t * point
            bounds.add point
          end
          min, max = bounds.min, bounds.max
          height = max.y - min.y
          width = max.x - min.x
          if (width - panel_max_width) > 0.1
            next
          end
          if (height - panel_max_height) > 0.1
            next
          end
          area = width * height
          if (not bounds_area) or ((bounds_area - area) > 0.1)
            bounds_area = area
            bounds_min, bounds_max = min, max
            transform = t
          end
        end
      end
  
      # If we still couldn't find a fitting, abort.
      if not transform
        @error = "Couldn't fit panel within cutting sheet"
        puts @error
        return
      end
  
      # Set the panel to a singleton panel (i.e. without any padding) if it is
      # larger than the height and width, otherwise set the no_padding flag.
      width = bounds_max.x - bounds_min.x
      height = bounds_max.y - bounds_min.y
      if (width + padding) > panel_width
        @no_padding = 'w'
      end
      if (height + padding) > panel_height
        if @no_padding
          @singleton = true
          @no_padding = nil
        else
          @no_padding = 'h'
        end
      end
  
      # Transform all points on every loop.
      loops.map! do |loop|
        loop.map! do |point|
          transform * point
        end
      end
  
      # Find the centroid.
      # uses the first area and centoid coordinates as these should be for the outer loop.
      # Then subtracts those of any inner loops. 
      @shell_area = surface_area = areas.shift
      topx = surface_area * cxs.shift
      topy = surface_area * cys.shift
      for i in 0...areas.length # Run through rest of areas, subtracting thier centroids * areas
        area = areas[i]
        topx -= area * cxs[i]
        topy -= area * cys[i]
        surface_area -= area
      end
      # Final centorid 
      cx = topx / surface_area
      cy = topy / surface_area
      centroid = transform * [cx, cy, 0]
  
      # Sanity check the surface area calculation.
      if (total_area - surface_area).abs > 0.1
        @error = "Surface area calculation differs"
        return
      end
  
      # TODO(tav): We could also detect arcs once we figure out how to create
      # polylined shapes with arcs in the DXF output. This may not be ideal as
      # polyarcs may also cause issues with certain CNC routers.
  
      # Detect all circular loops.
      for i in 0...loops.length
        points = intersections[i]
        length = points.length
        last = length - 1
        circle = true
        for j in 0...length
          c1 = points[j]
          c2 = points[j+1]
          if j == last
            c2 = points[0]
          end
          if not (c1 and c2)
            circle = false
            break
          end
          if ((c2.x - c1.x).abs > 0.1) or ((c2.y - c1.y).abs > 0.1)
            circle = false
            break
          end
        end
        if circle and length >= 24
          center = transform * points[0]
          p1 = loops[i][0]
          x = center.x - p1.x
          y = center.y - p1.y
          radius = Math.sqrt((x * x) + (y * y))
          circles[i] = [center, radius]
        end
      end
  
      # Save the generated data.
      @area = total_area
      @bounds_area = bounds_area
      @centroid = centroid
      @circles = circles
      @loops = loops
      @max = bounds_max
      @min = bounds_min
  
      # Delete any temporarily generated groups.
      if to_delete.length > 0
        root.erase_entities to_delete
      end
  
    end
  
  end
  
  # ------------------------------------------------------------------------------
  # Entities Loader
  # ------------------------------------------------------------------------------
  
  class WikiHouseEntities
    
    attr_accessor :orphans, :panels
  
    def initialize(entities, root, dimensions)
  
      $count_s1 = 0
      $count_s2 = 0
      $count_s3 = 0
      $count_s4 = 0
  
      # Initialise the default attribute values.
      @faces = Hash.new
      @groups = groups = Hash.new
      @orphans = orphans = Hash.new
      @root = root
      @to_delete = []
      @todo = todo = []
  
      # Set a loop counter variable and the default identity transformation.
      loop = 0
      transform = Geom::Transformation.new
  
      # Aggregate all the entities into the ``todo`` array.
      entities.each { |entity| todo << [entity, transform] }
  
      # Visit all component and group entities defined within the model and count
      # up all orphaned face entities.
      while todo.length != 0
        Sketchup.set_status_text WIKIHOUSE_DETECTION_STATUS[(loop/10) % 5] # Loop through status msg 
        loop += 1
        entity, transform = todo.pop
        case entity.typename
        when "Group", "ComponentInstance"
          visit entity, transform
        when "Face" 
          if orphans[WIKIHOUSE_DUMMY_GROUP]
            orphans[WIKIHOUSE_DUMMY_GROUP] += 1
          else
            orphans[WIKIHOUSE_DUMMY_GROUP] = 1
          end
        end
      end
  
      # If there were no orphans, unset the ``@orphans`` attribute.
      if not orphans.length > 0
        @orphans = nil
      end
  
      # Reset the loop counter.
      loop = 0
  
      # Construct the panel limit dimensions.
      height, width, padding = [dimensions[2], dimensions[3], dimensions[5]]
      padding = 2 * padding
      limits = [height - padding, width - padding, height, width, padding]
  
      # Loop through each group and aggregate parsed data for the faces.
      @panels = items = []
      @faces.each_pair do |group, faces|
        meta = groups[group]
        sample = faces[0]
        if meta.length == 1
          f_data = { meta[0][0] => [meta[0][1]] }
        else
          f_data = Hash.new
          meta = meta.map { |t, l| [t, l, sample.area(t)] }.sort_by { |t| t[2] }
          while meta.length != 0
            t1, l1, a1 = meta.pop
            idx = -1
            f_data[t1] = [l1]
            while 1
              f2_data = meta[idx]
              if not f2_data
                break
              end
              t2, l2, a2 = f2_data
              if (a2 - a1).abs > 0.1
                break
              end
              f_data[t1] << l2
              meta.delete_at idx
            end
          end
        end
        f_data.each_pair do |transform, labels|
          panels = faces.map do |face|
            Sketchup.set_status_text WIKIHOUSE_PANEL_STATUS[(loop/3) % 5]
            loop += 1
            WikiHousePanel.new root, face, transform, labels, limits
          end
          items.concat panels
        end
      end
  
      total = 0
      items.each { |item| total += item.labels.length }
  
      if @orphans
        puts "Orphans: #{@orphans.length} Groups"
      end
  
      puts "Items: #{total}"
      puts "S1: #{$count_s1}"
      puts "S2: #{$count_s2}"
      puts "S3: #{$count_s3}"
      puts "S4: #{$count_s4}"
      
    end
  
    def visit(group, transform)
  
      # Setup some local variables.
      exists = false
      faces = []
      groups = @groups
  
      # Setup the min/max heights for the depth edge/faces.
      min_height = $wikihouse_settings["sheet_depth"] - 1.mm
      max_height = $wikihouse_settings["sheet_depth"] + 1.mm
#      min_height = 17.mm
#      max_height = 19.mm
  
      # Apply the transformation if one has been set for this group.
      if group.transformation
        transform = transform * group.transformation
      end
  
      # Get the label.
      label = group.name
      if label == ""
        label = nil
      end
  
      # Get the entities set.
      case group.typename
      when "Group"
        entities = group.entities
      else # is component
        group = group.definition
        entities = group.entities
        # Check if we've seen this component before, and if so, reuse previous
        # data.
        if groups[group]
          groups[group] << [transform, label]
          entities.each do |entity|
            case entity.typename
            when "Group", "ComponentInstance"
              @todo << [entity, transform]
            end
          end
          return
        end
      end
  
      # Add the new group/component definition.
      groups[group] = [[transform, label]]
  
      # Loop through the entities.
      entities.each do |entity|
        case entity.typename
        when "Face"
          edges = entity.edges
          ignore = 0
          # Ignore all faces which match the specification for the depth side.
          if edges.length == 4
            for i in 0...4
              edge = edges[i]
              length = edge.length
              if length < max_height and length > min_height
                ignore += 1
                if ignore == 2
                  break
                end
              end
            end
          end
          if WIKIHOUSE_HIDE and ignore == 2
            entity.hidden = false
          end
          if ignore != 2 # TODO(tav): and entity.visible?
            faces << entity
          end
        when "Group", "ComponentInstance"
          # Append the entity to the todo attribute instead of recursively calling
          # ``visit`` so as to avoid blowing the stack.
          @todo << [entity, transform]
        end
      end
  
      faces, orphans = visit_faces faces, transform
  
      if orphans and orphans.length > 0
        @orphans[group] = orphans.length
      end
  
      if faces and faces.length > 0
        @faces[group] = faces
      end
  
    end
  
    def visit_faces(faces, transform)
  
      # Handle the case where no faces have been found or just a single orphaned
      # face exists.
      if faces.length <= 1
        if faces.length == 0
          return [], nil
        else
          return [], faces
        end
      end
  
      # Define some local variables.
      found = []
      orphans = []
  
      # Sort the faces by their respective surface areas in order to minimise
      # lookups.
      faces = faces.sort_by { |face| face.area transform }
  
      # Iterate through the faces and see if we can find matching pairs.
      while faces.length != 0
        face1 = faces.pop
        area1 = face1.area transform
        # Ignore small faces.
        if area1 < 5  # (Chris) This may be why the small C shaped parts in Joins are being ignored. 
          next
        end
        idx = -1
        match = false
        # Check against all remaining faces.
        while 1
          face2 = faces[idx]
          if not face2
            break
          end
          if face1 == face2
            faces.delete_at idx
            next
          end
          # Check that the area of both faces are close enough -- accounting for
          # any discrepancies caused by floating point rounding errors.
          area2 = face2.area transform
          diff = (area2 - area1).abs
          if diff < 0.5 # TODO(tav): Ideally, this tolerance will be 0.1 or less.
            $count_s1 += 1
            # Ensure that the faces don't intersect, i.e. are parallel to each
            # other.
            intersect = Geom.intersect_plane_plane face1.plane, face2.plane
            if intersect
              # Calculate the angle between the two planes and accomodate for
              # rounding errors.
              angle = face1.normal.angle_between face2.normal
              if angle < 0.01
                intersect = nil
              elsif (Math::PI - angle).abs < 0.01
                intersect = nil
              end
            end
            if not intersect
              $count_s2 += 1
              vertices1 = face1.vertices
              vertices2 = face2.vertices
              vertices_length = vertices1.length
              # Check if both faces have matching number of outer vertices and
              # that they each share a common edge.
              vertices1 = face1.outer_loop.vertices
              vertices2 = face2.outer_loop.vertices
              for i in 0...vertices1.length
                vertex1 = vertices1[i]
                connected = false
                for j in 0...vertices2.length
                  vertex2 = vertices2[j]
                  if vertex1.common_edge vertex2
                    connected = true
                    vertices2.delete_at j
                    break
                  end
                end
                if not connected
                  break
                end
              end
              if connected
                $count_s3 += 1
                # Go through the various loops of edges and find ones that have
                # shared edges to the other face.
                loops1 = []
                loops2 = []
                loops2_lengths = []
                face2.loops.each do |loop|
                  if not loop.outer?
                    loops2 << loop
                    loops2_lengths << loop.vertices.length
                  end
                end
                face1_loops = face1.loops
                face1_loops.each do |loop1|
                  if not loop1.outer?
                    loop1_vertices = loop1.vertices
                    loop1_length = loop1_vertices.length
                    for l in 0...loops2.length
                      if loops2_lengths[l] == loop1_length
                        loop2_vertices = loops2[l].vertices
                        for i in 0...loop1_length
                          v1 = loop1_vertices[i]
                          connected = false
                          for j in 0...loop2_vertices.length
                            v2 = loop2_vertices[j]
                            if v1.common_edge v2
                              connected = true
                              loop2_vertices.delete_at j
                              break
                            end
                          end
                          if not connected
                            break
                          end
                        end
                        if connected
                          loops1 << loops2[l].vertices
                          loops2.delete_at l
                          loops2_lengths.delete_at l
                          break
                        end
                      end
                    end
                  end
                end
                # If the number of loops with shared edges don't match up with the
                # original state, create a new face.
                if loops1.length != (face1.loops.length - 1)
                  group = @root.add_group
                  group_ents = group.entities
                  face = group_ents.add_face vertices1
                  loops1.each do |v|
                    hole = group_ents.add_face v
                    hole.erase! if hole.valid?
                  end
                  @to_delete << group
                else
                  face = face1
                end
                # We have matching and connected faces!
                match = true
                found << face
                faces.delete_at idx
                if WIKIHOUSE_HIDE
                  face1.hidden = true
                  face2.hidden = true
                end
                break
              end
            end
          end
          idx -= 1
        end
        if match
          next
        end
        orphans << face1
      end
  
      # Return all the found and orphaned faces.
      return found, orphans
  
    end
  
    def purge
  
      # Delete any custom generated entity groups.
      if @to_delete and @to_delete.length != 0
        @root.erase_entities @to_delete
      end
  
      # Nullify all container attributes.
      @faces = nil
      @groups = nil
      @orphans = nil
      @root = nil
      @to_delete = nil
      @todo = nil
  
    end
  
  end
  
  # ------------------------------------------------------------------------------
  # Make This House
  # ------------------------------------------------------------------------------
  def make_wikihouse(model, interactive)
  
    # Isolate the entities to export.
    entities = root = model.active_entities
    selection = model.selection
    if selection.empty?
      if interactive
        reply = UI.messagebox "No objects selected. Export the entire model?", MB_OKCANCEL
        if reply != REPLY_OK
          return
        end
      end
    else
      entities = selection
    end
  
    dimensions = [
              $wikihouse_settings["sheet_height"],
              $wikihouse_settings["sheet_width"],
              $wikihouse_settings["sheet_inner_height"],
              $wikihouse_settings["sheet_inner_width"],
              $wikihouse_settings["margin"],
              $wikihouse_settings["padding"],
              $wikihouse_settings["font_height"]
                ]
  
    # Load and parse the entities.
    if WIKIHOUSE_SHORT_CIRCUIT and $wikloader
      loader = $wikloader
    else
      loader = WikiHouseEntities.new entities, root, dimensions
      $wikloader = loader
      if WIKIHOUSE_SHORT_CIRCUIT
        $wikloader = loader
      end
    end
  
    if interactive and loader.orphans
      msg = "The cutting sheets may be incomplete. The following number of faces could not be matched appropriately:\n\n"
      loader.orphans.each_pair do |group, count|
        msg += "    #{count} in #{group.name.length > 0 and group.name or 'Group#???'}\n"
      end
      UI.messagebox msg
    end
  
    # Filter out any panels which raised an error.
    panels = loader.panels.select { |panel| !panel.error }
  
    # Run the detected panels through the layout engine.
    layout = WikiHouseLayoutEngine.new panels, root, dimensions
  
    # Generate the SVG file.
    svg = WikiHouseSVG.new layout, 8
    svg_data = svg.generate
  
    # Generate the DXF file.
    dxf = WikiHouseDXF.new layout
    dxf_data = dxf.generate
  
    # Cleanup.
    Sketchup.set_status_text ""
    loader.purge
  
    # Return the generated data.
    [svg_data, dxf_data]
  
  end
  
end

# ------------------------------------------------------------------------------
# Set Globals
# ------------------------------------------------------------------------------
# This section is run only once and sets up the Extension menu items and tool buttons.
# It in not part of module named WIkihouseExtension, so methods etc. must be referenced with 
# WikihouseExtension::name, where name is the name of the method, constant or class.

if not file_loaded? __FILE__

  WIKIHOUSE_ASSETS = File.join File.dirname(__FILE__), "wikihouse-assets"

  # Initialise the data containers.
  WIKIHOUSE_DOWNLOADS = Hash.new
  WIKIHOUSE_UPLOADS = Hash.new

  # Initialise the downloads counter.
  $WIKIHOUSE_DOWNLOADS_ID = 0

  # Initialise the core commands.
  WIKIHOUSE_DOWNLOAD = UI::Command.new "Get Models..." do
    WikihouseExtension::load_wikihouse_download
  end
  
  WIKIHOUSE_DOWNLOAD.tooltip = "Find new models to use at #{WikihouseExtension::WIKIHOUSE_TITLE}"
  WIKIHOUSE_DOWNLOAD.small_icon = File.join WIKIHOUSE_ASSETS, "download-16.png"
  WIKIHOUSE_DOWNLOAD.large_icon = File.join WIKIHOUSE_ASSETS, "download.png"

  # TODO(tav): Irregardless of these procs, all commands seem to get greyed out
  # when no models are open -- at least, on OS X.
  WIKIHOUSE_DOWNLOAD.set_validation_proc {
    MF_ENABLED
  }

  WIKIHOUSE_MAKE = UI::Command.new "Make This House..." do
    WikihouseExtension::load_wikihouse_make
  end

  WIKIHOUSE_MAKE.tooltip = "Convert a model of a House into printable components"
  WIKIHOUSE_MAKE.small_icon = File.join WIKIHOUSE_ASSETS, "make-16.png"
  WIKIHOUSE_MAKE.large_icon = File.join WIKIHOUSE_ASSETS, "make.png"
  WIKIHOUSE_MAKE.set_validation_proc {
    if Sketchup.active_model
      MF_ENABLED
    else
      MF_DISABLED|MF_GRAYED
    end
  }
  
  WIKIHOUSE_UPLOAD = UI::Command.new "Share Model..." do
    WikihouseExtension::load_wikihouse_upload
  end

  WIKIHOUSE_UPLOAD.tooltip = "Upload and share your model at #{WikihouseExtension::WIKIHOUSE_TITLE}"
  WIKIHOUSE_UPLOAD.small_icon = File.join WIKIHOUSE_ASSETS, "upload-16.png"
  WIKIHOUSE_UPLOAD.large_icon = File.join WIKIHOUSE_ASSETS, "upload.png"
  WIKIHOUSE_UPLOAD.set_validation_proc {
    if Sketchup.active_model
      MF_ENABLED
    else
      MF_DISABLED|MF_GRAYED
    end
  }
  
  WIKIHOUSE_SETTINGS = UI::Command.new "Settings..." do
  WikihouseExtension::load_wikihouse_settings
  end

  WIKIHOUSE_SETTINGS.tooltip = "Change #{WikihouseExtension::WIKIHOUSE_TITLE} settings"
  WIKIHOUSE_SETTINGS.small_icon = File.join WIKIHOUSE_ASSETS, "cog-16.png"
  WIKIHOUSE_SETTINGS.large_icon = File.join WIKIHOUSE_ASSETS, "cog.png"
  WIKIHOUSE_SETTINGS.set_validation_proc {
    MF_ENABLED
    }
  

  # Register a new toolbar with the commands.
  WIKIHOUSE_TOOLBAR = UI::Toolbar.new WikihouseExtension::WIKIHOUSE_TITLE
  WIKIHOUSE_TOOLBAR.add_item WIKIHOUSE_DOWNLOAD
  WIKIHOUSE_TOOLBAR.add_item WIKIHOUSE_UPLOAD
  WIKIHOUSE_TOOLBAR.add_item WIKIHOUSE_MAKE
  WIKIHOUSE_TOOLBAR.add_item WIKIHOUSE_SETTINGS
  WIKIHOUSE_TOOLBAR.show

  # Register a new submenu of the standard Plugins menu with the commands.
  WIKIHOUSE_MENU = UI.menu("Plugins").add_submenu WikihouseExtension::WIKIHOUSE_TITLE
  WIKIHOUSE_MENU.add_item WIKIHOUSE_DOWNLOAD
  WIKIHOUSE_MENU.add_item WIKIHOUSE_UPLOAD
  WIKIHOUSE_MENU.add_item WIKIHOUSE_MAKE
  WIKIHOUSE_MENU.add_item WIKIHOUSE_SETTINGS

  # Add our custom AppObserver.
  Sketchup.add_observer WikihouseExtension::WikiHouseAppObserver.new

  # Display the Ruby Console in dev mode.
  if WikihouseExtension::WIKIHOUSE_DEV
    Sketchup.send_action "showRubyPanel:"
    
    WE = WikihouseExtension
    
    def w
      load "wikihouse.rb"
    end
    puts ""
    puts "#{WikihouseExtension::WIKIHOUSE_TITLE} Extension Successfully Loaded."
    puts ""
    
    # Interactive utilities
    def mod
      return Sketchup.active_model # Open model
    end
    def ent
      return Sketchup.active_model.entities # All entities in model
    end
    def sel 
      return Sketchup.active_model.selection # Current selection
    end
  end

  file_loaded __FILE__

end


#def test
#  load "wikihouse.rb"
#  puts
#  data = make_wikihouse Sketchup.active_model, false
#  if data
#    filename = "/Users/tav/Documents/sketchup/Wikhouse10_tester3.svg"
#    svg_data, dxf_data = data
#    # Save the SVG data to the file.
#    File.open(filename, "wb") do |io|
#      io.write svg_data
#    end
#    "Sheets generated!"
#  end