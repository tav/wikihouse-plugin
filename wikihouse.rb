# Public Domain (-) 2011 The WikiHouse Authors.
# See the WikiHouse UNLICENSE file for details.

# =========================
# WikiHouse SketchUp Plugin
# =========================

require 'sketchup.rb'

# ------------------------------------------------------------------------------
# Path Utilities
# ------------------------------------------------------------------------------

def get_documents_directory(home, docs)
  dir = File.join home, docs
  if not (File.directory?(dir) and File.writable?(dir))
    home
  else
    dir
  end
end

def get_temp_directory
  temp = '.'
  for dir in [ENV['TMPDIR'], ENV['TMP'], ENV['TEMP'], ENV['USERPROFILE'], '/tmp']
	if dir and File.directory?(dir) and File.writable?(dir)
	  temp = dir
	  break
	end
  end
  File.expand_path temp
end

# ------------------------------------------------------------------------------
# Some Constants
# ------------------------------------------------------------------------------

PANEL_ID_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
PANEL_ID_ALPHABET_LENGTH = PANEL_ID_ALPHABET.length

REPLY_ABORT = 3
REPLY_CANCEL = 2
REPLY_NO = 7
REPLY_OK = 1
REPLY_RETRY = 4
REPLY_YES = 6

if RUBY_PLATFORM =~ /mswin/
  WIKIHOUSE_CONF_FILE = File.join ENV['APPDATA'], 'WikiHouse.conf'
  WIKIHOUSE_SAVE = get_documents_directory ENV['USERPROFILE'], 'Documents'
  WIKIHOUSE_MAC = false
else
  WIKIHOUSE_CONF_FILE = File.join ENV['HOME'], '.wikihouse.conf'
  WIKIHOUSE_SAVE = get_documents_directory ENV['HOME'], 'Documents'
  WIKIHOUSE_MAC = true
end

WIKIHOUSE_DEV = false
WIKIHOUSE_HIDE = false

if WIKIHOUSE_DEV
  WIKIHOUSE_SERVER = "http://localhost:8080"
else
  WIKIHOUSE_SERVER = "https://wikihouse-cc.appspot.com"
end

WIKIHOUSE_DOWNLOAD_PATH = "/library/sketchup"
WIKIHOUSE_UPLOAD_PATH = "/library/designs/add/sketchup"
WIKIHOUSE_DOWNLOAD_URL = WIKIHOUSE_SERVER + WIKIHOUSE_DOWNLOAD_PATH
WIKIHOUSE_UPLOAD_URL = WIKIHOUSE_SERVER + WIKIHOUSE_UPLOAD_PATH

WIKIHOUSE_PLUGIN_VERSION = "0.1"
WIKIHOUSE_SPEC = "0.1"
WIKIHOUSE_TEMP = get_temp_directory
WIKIHOUSE_TITLE = "WikiHouse"

# ------------------------------------------------------------------------------
# Utility Functions
# ------------------------------------------------------------------------------

def gen_status_msg(msg)
  return [
    msg + " .",
    msg + " ..",
    msg + " ...",
    msg + " ....",
    msg + " .....",
  ]
end

def get_wikihouse_thumbnail(model, view, suffix)
  filename = File.join WIKIHOUSE_TEMP, "#{model.guid}-#{suffix}.png"
  opts = {
    :antialias => true,
    :compression => 0.8,
    :filename => filename,
    :height => [view.vpheight, 1600].min,
    :transparent => true,
    :width => [view.vpwidth, 1600].min
  }
  view.write_image opts
  data = File.open(filename, 'rb') do |io|
    io.read
  end
  File.delete filename
  data
end

def set_dom_value(dialog, id, value)
  if value.length > 2097152
    dialog.execute_script "WIKIHOUSE_DATA = [#{value[0...2097152].inspect}];"
    start, stop = 2097152, (2097152+2097152)
    idx = 1
    while 1
      segment = value[start...stop]
      if not segment
        break
      end
      dialog.execute_script "WIKIHOUSE_DATA[#{idx}] = #{segment.inspect};"
      idx += 1
      start = stop
      stop = stop + 2097152
    end
    dialog.execute_script "document.getElementById('#{id}').value = WIKIHOUSE_DATA.join('');"
  else
    dialog.execute_script "document.getElementById('#{id}').value = #{value.inspect};"
  end
end

def show_wikihouse_error(msg)
  UI.messagebox "!! ERROR !!\n\n#{msg}"
end

# ------------------------------------------------------------------------------
# Centroid Calculation
# ------------------------------------------------------------------------------

def get_face_center(face)

  # First, triangulate the polygon.
  mesh = face.mesh

  # Initialise aggregation variables.
  idx = 0
  xs = []
  ys = []
  areas = []

  # For each triangle, calculate the surface area and center of mass.
  for i in 0...mesh.count_polygons

    a, b, c = mesh.polygon_points_at i+1

    ax, ay, _ = a.to_a
    bx, by, _ = b.to_a
    cx, cy, _ = c.to_a

    dax = ax - bx
    dbx = bx - cx
    dcx = cx - ax
    day = ay - by
    dby = by - cy
    dcy = cy - ay

    la = Math.sqrt((dax * dax) + (day * day))
    lb = Math.sqrt((dbx * dbx) + (dby * dby))
    lc = Math.sqrt((dcx * dcx) + (dcy * dcy))

    px = ((ax * la) + (ax * lb) + (cx * lc)) / (la + lb + lc)
    py = ((ay * la) + (ay * lb) + (cy * lc)) / (la + lb + lc)

    # angle = (Math.acos((la * la) + (lb * lb) - (lc * lc)) * Math::PI) / (360 * la * lb)
    # area = (la * lb * Math.sin(angle)) / 2

    s1, s2, s3 = [la, lb, lc].sort.reverse
    top = (s1 + (s2 + s3)) * (s3 - (s1 - s2)) * (s3 + (s1 - s2)) * (s1 + (s2 - s3))

    # TODO(tav): Read http://www.eecs.berkeley.edu/~wkahan/Triangle.pdf and
    # figure out why this fails on triangles with small angles.
    if top < 0
      puts "Failed surface area calculation"
      next
    end

    area = Math.sqrt(top) / 4

    xs[idx] = px
    ys[idx] = py
    areas[idx] = area

    idx += 1

  end

  # Calculate the total surface area.
  total = areas.inject(0) { |t, a| a + t }

  # Calculate the weighted center points.
  px, py = 0, 0
  for i in 0...xs.length
    x, y, a = xs[i], ys[i], areas[i]
    px += x * a
    py += y * a
  end

  # Calculate the center of mass.
  px = px / total
  py = py / total

  [px, py]

end

# ------------------------------------------------------------------------------
# Status Messages
# ------------------------------------------------------------------------------

WIKIHOUSE_DETECTION_STATUS = gen_status_msg "Detecting matching faces"
WIKIHOUSE_PANEL_STATUS = gen_status_msg "Generating panel data"

# ------------------------------------------------------------------------------
# Load Handler
# ------------------------------------------------------------------------------

class WikiHouseLoader

  attr_accessor :cancel, :error

  def initialize(name)
    @cancel = false
    @error = nil
    @name = name
  end

  def cancelled?
    @cancel
  end

  def onFailure(error)
    @error = error
    Sketchup.set_status_text ''
  end

  def onPercentChange(p)
    Sketchup.set_status_text "LOADING #{name}:    #{p.to_i}%"
  end

  def onSuccess
    Sketchup.set_status_text ''
  end

end

# ------------------------------------------------------------------------------
# App Observer
# ------------------------------------------------------------------------------

class WikiHouseAppObserver < Sketchup::AppObserver

  def onNewModel(model)
  end

  # TODO(tav): This doesn't seem to be getting called.
  def onQuit
    if WIKIHOUSE_DOWNLOADS.length > 0
      show_wikihouse_error "Aborting downloads from #{WIKIHOUSE_TITLE}"
    end
    if WIKIHOUSE_UPLOADS.length > 0
      show_wikihouse_error "Aborting uploads to #{WIKIHOUSE_TITLE}"
    end
  end

end

# ------------------------------------------------------------------------------
# Dummy Group
# ------------------------------------------------------------------------------

class WikiHouseDummyGroup

  attr_accessor :name

  def initialize
    @name = "Ungrouped Objects"
  end

end

WIKIHOUSE_DUMMY_GROUP = WikiHouseDummyGroup.new

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

  def initialize(layout)
  end

  def generate
    ""
  end

end

# ------------------------------------------------------------------------------
# Layout Engine
# ------------------------------------------------------------------------------

class WikiHouseLayoutEngine

  def initialize(panels)
  end

end

# ------------------------------------------------------------------------------
# Panel
# ------------------------------------------------------------------------------

class WikiHousePanel

  attr_accessor :count, :error, :identifier

  def initialize(root, recycle, face, transform, group_id, face_id, count)

    # Initalise the ``identifier``, ``error`` and ``count`` attributes.
    @count = count
    @error = true
    @identifier = "#{group_id}-#{face_id}"

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
    area = face.area

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

    # Initialise various container variables.
    curves = Hash.new
    curve_info = Hash.new
    last_curve_id = 0
    loops, outer = [], []
    slanted = false

    # Initialise a reference point for transforming slanted faces.
    base = face.outer_loop.vertices[0].position

    # Loop through the edges -- ensuring that we are traversing them in the
    # right order.
    face.loops.each do |loop|
      if loop.outer?
        newloop = outer
      else
        newloop = []
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
            puts "Unexpected edge connection"
            return
          end
          virgin = nil
        else
          start = edge.start
          stop = edge.end
          if stop == prev
            stop, start = start, stop
          elsif not start == prev
            puts "Unexpected edge connection"
            return
          end
        end
        curve = edge.curve
        if curve
          curve_id = curves[curve]
          if not curve_id
            curve_id = last_curve_id
            curves[curve] = curve_id
            curve_info[curve_id] = [1, curve.center, curve.radius]
            last_curve_id += 1
          else
            curve_info[curve_id][0] += 1
          end
        else
          curve_id = nil
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
          slanted = true
        end
        edgeuse = edgeuse.next
        if edgeuse == first
          break
        end
        prev = stop
      end
    end

    if curves.length > 0
      if slanted
        puts "slanted"
      end
      puts curve_info.inspect
    end

    # Go through the various loops and identify potential curves.
    nloops = [outer]
    nloops.concat loops
    nloops.each do |loop|
      idx = 0
      prev = nil
      while 1
        # Get the next three points on the loop.
        p1, p2, p3 = loop[idx...idx+3]
        if not p3
          break
        end
        # Construct the edge vectors.
        edge1 = Geom::Vector3d.new(p2.x - p1.x, p2.y - p1.y, p2.z - p1.z)
        edge2 = Geom::Vector3d.new(p3.x - p2.x, p3.y - p2.y, p3.z - p2.z)
        if edge1.parallel? edge2
          idx += 1
          prev = nil
          next
        end
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
        puts intersect.inspect
        # If no intersection, try finding one in the other direction.
        if not intersect
          vec1.reverse!
          vec2.reverse!
          intersect = Geom.intersect_line_line line1, line2
        end
        if not intersect
          idx += 1
          prev = nil
          next
        end
        # We have an intersection!
        idx += 1
        prev = edge1
      end
      puts "----"
    end
    puts "====="

    # Generate the new 2D face.
    if nil
      group_entity = root.add_group
      to_delete << group_entity
      group = group_entity.entities
      newface = group.add_face outer
      loops.each do |loop|
        hole = group.add_face loop
        hole.erase! if hole.valid?
      end
      puts face.area
      puts newface.area
    end

    # Find the orientation occupying the minimal bounding rectangle.
    # vertices = face.outer_loop.vertices

    # Find the centre of the face.

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

  attr_accessor :component_orphans, :deleted, :orphan_count, :orphans, :panels

  def initialize(entities, root)

    $count_s1 = 0
    $count_s2 = 0
    $count_s3 = 0
    $count_s4 = 0

    # Create a group to hold temporary entities.
    recycle = root.add_group

    # Initialise the default attribute values.
    @component_orphans = Hash.new
    @count = count = Hash.new
    @faces = Hash.new
    @group_orphans = Hash.new
    @groups = []
    @orphan_count = oc = Hash.new
    @orphans = orphans = []
    @root = root
    @to_delete = [recycle]
    @todo = todo = []

    # Set a loop counter variable and the default identity transformation.
    loop = 0
    transform = Geom::Transformation.new

    # Aggregate all the entities into the ``todo`` array.
    entities.each { |entity| todo << [entity, transform] }

    # Visit all component and group entities defined within the model and
    # accumulate all orphaned face entities.
    while todo.length != 0
      Sketchup.set_status_text WIKIHOUSE_DETECTION_STATUS[(loop/10) % 5]
      loop += 1
      entity, transform = todo.pop
      case entity.typename
      when "Group", "ComponentInstance"
        visit entity, transform
      when "Face"
        orphans << [entity, transform]
      end
    end

    # Try and see if any orphaned faces link up.
    faces, orphans = visit_faces orphans, true

    # If any orphans remain, update the ``@orphans`` attribute.
    if orphans and orphans.length > 0
      @orphans = orphans
      orphans.each do |data|
        orphan = data[0]
        parent = orphan.parent
        if not parent
          parent = WIKIHOUSE_DUMMY_GROUP
        end
        if oc[parent]
          oc[parent] += 1
        else
          oc[parent] = 1
        end
      end
    else
      @orphans = nil
    end

    @component_orphans.each_pair do |component, orphans|
      oc[component] = orphans.length
    end

    # But, if we got some faces back, update ``@faces``.
    if faces and faces.length > 0
      @faces["0"] = faces
    end

    # Reset the loop counter.
    loop = 0

    # Loop through each group and aggregate parsed data for the faces.
    @panels = items = []
    group_id = 0
    @faces.each_pair do |group, faces|
      if group == "0"
        face_id = 0
        panels = faces.map do |data|
          face_id += 1
          Sketchup.set_status_text WIKIHOUSE_PANEL_STATUS[(loop/10) % 5]
          loop += 1
          WikiHousePanel.new root, recycle, data[0], data[1], "0", face_id, 1
        end
        items.concat panels
      else
        transforms = count[group]
        sample = faces[0][0]
        if transforms.length == 1
          t_data = { transforms[0] => 1 }
        else
          t_data = Hash.new
          transforms = transforms.map { |t| [t, sample.area(t)] }.sort_by { |t| t[1] }
          while transforms.length != 0
            t1, a1 = transforms.pop
            idx = -1
            t_data[t1] = 1
            while 1
              t2_data = transforms[idx]
              if not t2_data
                break
              end
              t2, a2 = t2_data
              if (a2 - a1).abs > 0.1
                break
              end
              t_data[t1] += 1
              transforms.delete_at idx
            end
          end
        end
        t_data.each_pair do |transform, panel_count|
          group_id_list = []
          cur = group_id
          while 1
            div = cur / PANEL_ID_ALPHABET_LENGTH
            mod = cur % PANEL_ID_ALPHABET_LENGTH
            group_id_list << mod
            if div == 0
              break
            end
            cur = div - 1
          end
          group_id_list.reverse!
          group_str = (group_id_list.map { |id| PANEL_ID_ALPHABET[id].chr }).join ""
          face_id = 0
          panels = faces.map do |data|
            face_id += 1
            Sketchup.set_status_text WIKIHOUSE_PANEL_STATUS[(loop/10) % 5]
            loop += 1
            WikiHousePanel.new root, recycle, data[0], transform, group_str, face_id, panel_count
          end
          group_id += 1
          items.concat panels
        end
      end
    end

    total = 0
    items.each { |item| total += item.count }

    if @orphans
      puts "Orphans: #{@orphans.length}"
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
    min_height = 17.mm
    max_height = 19.mm

    # Apply the transformation if one has been set for this group.
    if group.transformation
      transform = transform * group.transformation
    end

    # Loop through previously visited groups and see if we've parsed any
    # equivalent shapes.
    for i in 0...groups.length
      prev_group = groups[i]
      if prev_group.equals? group and not @group_orphans[prev_group]
        exists = true
        @count[prev_group] << transform
        break
      end
    end

    # If so, exit early.
    return if exists

    # Otherwise, add the new group/component instance.
    groups << group
    @count[group] = [transform]

    # Get the entities set.
    case group.typename
    when "Group"
      entities = group.entities
      is_group = true
    else
      entities = group.definition.entities
      is_group = false
    end

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
          faces << [entity, transform]
        end
      when "Group", "ComponentInstance"
        # Append the entity to the todo attribute instead of recursively calling
        # ``visit`` so as to avoid blowing the stack.
        @todo << [entity, transform]
      end
    end

    faces, orphans = visit_faces faces, true

    if orphans and orphans.length > 0
      if is_group
        @group_orphans[group] = true
        @orphans.concat orphans
      else
        @component_orphans[group] = orphans
      end
    end

    if faces and faces.length > 0
      @faces[group] = faces
    end

  end

  def visit_faces(faces, force)

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
    faces = faces.sort_by { |data| data[0].area data[1] }

    # Iterate through the faces and see if we can find matching pairs.
    while faces.length != 0
      face1, transform1 = faces.pop
      area1 = face1.area transform1
      # Ignore small faces.
      if area1 < 5
        next
      end
      idx = -1
      match = false
      # Check against all remaining faces.
      while 1
        face2, transform2 = faces[idx]
        if not face2
          break
        end
        if face1 == face2
          faces.delete_at idx
          next
        end
        # Check that the area of both faces are close enough -- accounting for
        # any discrepancies caused by floating point rounding errors.
        area2 = face2.area transform2
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
              found << [face, transform1]
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
      orphans << [face1, transform1]
    end

    # Return all the found and orphaned faces.
    return found, orphans

  end

  def purge

    # Delete any custom generated entity groups.
    if @to_delete.length != 0
      @root.erase_entities @to_delete
    end

    # Nullify all container attributes.
    @component_orphans = nil
    @count = nil
    @faces = nil
    @group_orphans = nil
    @groups = nil
    @orphan_count = nil
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
  entities = model.active_entities
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

  # Load and parse the entities.
  loader = WikiHouseEntities.new entities, model.active_entities

  if interactive and loader.orphan_count.length != 0
    msg = "The cutting sheets may be incomplete. The following number of faces could not be matched appropriately:\n\n"
    loader.orphan_count.each_pair do |group, count|
      msg += "    #{count} in #{group.name.length > 0 and group.name or 'Group#???'}\n"
    end
    UI.messagebox msg
  end

  # Run the detected panels through the layout engine.
  layout = WikiHouseLayoutEngine.new loader.panels

  # Generate the SVG file.
  svg = WikiHouseSVG.new layout
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

# ------------------------------------------------------------------------------
# Download Callbacks
# ------------------------------------------------------------------------------

def wikihouse_download_callback(dialog, params)
  
  # Exit if the download parameters weren't set.
  if params == ""
    show_wikihouse_error "Couldn't find the #{WIKIHOUSE_TITLE} model name and url"
    return
  end

  is_comp, base64_url, blob_url, name = params.split ",", 4
  model = Sketchup.active_model

  # Try and save the model/component directly into the current model.
  if model and is_comp == '1'
    reply = UI.messagebox "Load this directly into your Google SketchUp model?", MB_YESNOCANCEL
    if reply == REPLY_YES
      loader = WikiHouseLoader.new name
      blob_url = WIKIHOUSE_SERVER + blob_url
      model.definitions.load_from_url blob_url, loader
      if not loader.error
        dialog.close
        UI.messagebox "Successfully downloaded #{name}"
        component = model.definitions[-1]
        if component
          model.place_component component
        end
        return
      else
        UI.messagebox loader.error
        reply = UI.messagebox "Would you like to save the model file instead?", MB_YESNO
        if reply == REPLY_NO
          return
        end
      end
    elsif reply == REPLY_NO
      # Skip through to saving the file directly.
    else
      return
    end
  end

  # Otherwise, get the filename to save into.
  filename = UI.savepanel "Save Model", WIKIHOUSE_SAVE, "#{name}.skp"
  if not filename
    show_wikihouse_error "No filename specified to save the #{WIKIHOUSE_TITLE} model. Please try again."
    return
  end

  # TODO(tav): Ensure that this is atomic and free of thread-related
  # concurrency issues.
  $WIKIHOUSE_DOWNLOADS_ID += 1
  download_id = $WIKIHOUSE_DOWNLOADS_ID.to_s

  WIKIHOUSE_DOWNLOADS[download_id] = filename

  # Initiate the download.
  dialog.execute_script "wikihouse.download('#{download_id}', '#{base64_url}');"

end

def wikihouse_save_callback(dialog, download_id)

  errmsg = "Couldn't find the #{WIKIHOUSE_TITLE} model data to save"

  # Exit if the save parameters weren't set.
  if download_id == ""
    show_wikihouse_error errmsg
    return
  end

  if not WIKIHOUSE_DOWNLOADS.key? download_id
    show_wikihouse_error errmsg
    return
  end

  filename = WIKIHOUSE_DOWNLOADS[download_id]
  WIKIHOUSE_DOWNLOADS.delete download_id

  data = dialog.get_element_value "design-download-data"
  dialog.close

  if data == ""
    show_wikihouse_error errmsg
    return
  end

  # Decode the base64-encoded data.
  data = data.unpack("m")[0]
  if data == ""
    show_wikihouse_error errmsg
    return
  end

  # Save the data to the local file.
  File.open(filename, 'wb') do |io|
    io.write data
  end

  reply = UI.messagebox "Successfully saved #{WIKIHOUSE_TITLE} model. Would you like to open it?", MB_YESNO
  if reply == REPLY_YES
    if not Sketchup.open_file filename
      show_wikihouse_error "Couldn't open #{filename}"
    end
  end

end

def wikihouse_error_callback(dialog, download_id)

  if not WIKIHOUSE_DOWNLOADS.key? download_id
    return
  end

  filename = WIKIHOUSE_DOWNLOADS[download_id]
  WIKIHOUSE_DOWNLOADS.delete download_id

  show_wikihouse_error "Couldn't download #{filename} from #{WIKIHOUSE_TITLE}. Please try again."

end

# ------------------------------------------------------------------------------
# Download Dialog
# ------------------------------------------------------------------------------

def load_wikihouse_download

  # Exit if the computer is not online.
  if not Sketchup.is_online
    UI.messagebox "You need to be connected to the internet to download #{WIKIHOUSE_TITLE} models."
    return
  end

  dialog = UI::WebDialog.new WIKIHOUSE_TITLE, true, "#{WIKIHOUSE_TITLE}-Download", 720, 640, 150, 150, true

  dialog.add_action_callback "download" do |dialog, params|
    wikihouse_download_callback dialog, params
  end

  dialog.add_action_callback "save" do |dialog, download_id|
    wikihouse_save_callback dialog, download_id
  end

  dialog.add_action_callback "error" do |dialog, download_id|
    wikihouse_error_callback dialog, download_id
  end

  # Set the dialog's url and display it.
  dialog.set_url WIKIHOUSE_DOWNLOAD_URL
  dialog.show
  dialog.bring_to_front

end

# ------------------------------------------------------------------------------
# Make Dialog
# ------------------------------------------------------------------------------

def load_wikihouse_make

  model = Sketchup.active_model

  # Exit if a model wasn't available.
  if not model
    show_wikihouse_error "You need to open a SketchUp model before it can be fabricated"
    return
  end

  # Initialise an attribute dictionary for custom metadata.
  attr = model.attribute_dictionary WIKIHOUSE_TITLE, true
  if attr.size == 0
    attr["spec"] = WIKIHOUSE_SPEC
  end

  # Exit if it's an unsaved model.
  model_path = model.path
  if model_path == ""
    UI.messagebox "You need to save the model before the cutting sheets can be generated"
    return
  end

  # Try and infer the model's filename.
  filename = model.title
  if filename == ""
    filename = "Untitled"
  end

  # Get the model's parent directory and generate the new filenames to save to.
  directory = File.dirname(model_path)
  svg_filename = File.join(directory, filename + ".svg")
  dxf_filename = File.join(directory, filename + ".dxf")

  # Make the cutting sheets for the house!
  data = make_wikihouse model, true
  if not data
    return
  end

  svg_data, dxf_data = data

  # Save the SVG data to the file.
  File.open(svg_filename, "wb") do |io|
    io.write svg_data
  end

  # Save the DXF data to the file.
  File.open(dxf_filename, "wb") do |io|
    io.write dxf_data
  end

  UI.messagebox "Cutting sheets successfully saved to #{directory}", MB_OK

  if WIKIHOUSE_MAC
    dialog = UI::WebDialog.new WIKIHOUSE_TITLE, true, "#{WIKIHOUSE_TITLE}-Preview", 720, 640, 150, 150, true
    dialog.set_file svg_filename
    dialog.show
    dialog.bring_to_front
  end

end

# ------------------------------------------------------------------------------
# Upload Dialog
# ------------------------------------------------------------------------------

def load_wikihouse_upload

  # Exit if the computer is not online.
  if not Sketchup.is_online
    UI.messagebox "You need to be connected to the internet to upload models to #{WIKIHOUSE_TITLE}."
    return
  end

  model = Sketchup.active_model

  # Exit if a model wasn't available.
  if not model
    show_wikihouse_error "You need to open a SketchUp model to share"
    return
  end

  # Initialise an attribute dictionary for custom metadata.
  attr = model.attribute_dictionary WIKIHOUSE_TITLE, true
  if attr.size == 0
    attr["spec"] = "0.1"
  end

  # Exit if it's an unsaved model.
  model_path = model.path
  if model_path == ""
    UI.messagebox "You need to save the model before it can be shared at #{WIKIHOUSE_TITLE}"
    return
  end

  # Auto-save the model if it has been modified.
  if model.modified?
    if not model.save model_path
      show_wikihouse_error "Couldn't auto-save the model to #{model_path}"
      return
    end
  end

  # Try and infer the model's name.
  model_name = model.name
  if model_name == ""
    model_name = model.title
  end

  # Instantiate an upload web dialog.
  dialog = UI::WebDialog.new WIKIHOUSE_TITLE, true, "#{WIKIHOUSE_TITLE}-Upload", 720, 640, 150, 150, true

  # Load default values into the upload form.
  dialog.add_action_callback "load" do |dialog, params|
    if model_name != ""
      if dialog.get_element_value("design-title") == ""
        set_dom_value dialog, "design-title", model_name
      end
    end
    if model.description != ""
      if dialog.get_element_value("design-description") == ""
        set_dom_value dialog, "design-description", model.description
      end
    end
    if Sketchup.version
      set_dom_value dialog, "design-sketchup-version", Sketchup.version
    end
    set_dom_value dialog, "design-plugin-version", WIKIHOUSE_PLUGIN_VERSION
  end

  # Process and prepare the model related data for upload.
  dialog.add_action_callback "process" do |dialog, params|

    if File.size(model_path) > 12582912
      reply = UI.messagebox "The model file is larger than 12MB. Would you like to purge unused objects, materials and styles?", MB_OKCANCEL
      if reply == REPLY_OK
        model.layers.purge_unused
        model.styles.purge_unused
        model.materials.purge_unused
        model.definitions.purge_unused
        if not model.save model_path
          show_wikihouse_error "Couldn't save the purged model to #{model_path}"
          dialog.close
          return
        end
        if File.size(model_path) > 12582912
          UI.messagebox "The model file is still larger than 12MB after purging. Please break up the file into smaller components."
          dialog.close
          return
        end
      else
        dialog.close
      end
    end

    # Get the model file data.
    model_data = File.open(model_path, 'rb') do |io|
      io.read
    end

    model_data = [model_data].pack('m')
    set_dom_value dialog, "design-model", model_data

    # Capture the current view info.
    view = model.active_view
    camera = view.camera
    eye, target, up = camera.eye, camera.target, camera.up
    center = model.bounds.center

    # Get the data for the model's front image.
    front_thumbnail = get_wikihouse_thumbnail model, view, "front"
    if not front_thumbnail
      show_wikihouse_error "Couldn't generate thumbnails for the model: #{model_name}"
      dialog.close
      return
    end

    front_thumbnail = [front_thumbnail].pack('m')
    set_dom_value dialog, "design-model-preview", front_thumbnail

    # Rotate the camera.
    rotate = Geom::Transformation.rotation center, Z_AXIS, 180.degrees
    camera.set eye.transform(rotate), center, Z_AXIS

    # Zoom out.
    # view = view.zoom_extents

    # Get the data for the model's back image.
    back_thumbnail = get_wikihouse_thumbnail model, view, "back"
    if not back_thumbnail
      camera.set eye, target, up
      show_wikihouse_error "Couldn't generate thumbnails for the model: #{model_name}"
      dialog.close
      return
    end

    back_thumbnail = [back_thumbnail].pack('m')
    set_dom_value dialog, "design-model-preview-reverse", back_thumbnail

    # Set the camera view back to the original setup.
    camera.set eye, target, up

    # Note: we could have also rotated the entities, e.g.
    # entities.transform_entities(rotate, entities.to_a)

    # Get the generated sheets data.
    sheets_data = make_wikihouse model, false
    if not sheets_data
      svg_data, dxf_data = "", ""
    else
      svg_data = [sheets_data[0]].pack('m')
      dxf_data = [sheets_data[1]].pack('m')
    end

    set_dom_value dialog, "design-sheets", dxf_data
    set_dom_value dialog, "design-sheets-preview", svg_data

    WIKIHOUSE_UPLOADS[dialog] = 1
    dialog.execute_script "wikihouse.upload();"

    # # Generate a temporary file to save the exported model.
    # filename = File.join(get_temp_directory, model.guid + ".dae")

    # # Initialise the export options.
    # export_opts = {
    #   :author_attribution  => true,
    #   :doublesided_faces   => true,
    #   :edges               => false,
    #   :materials_by_layer  => false,
    #   :preserve_instancing => true,
    #   :selectionset_only   => false,
    #   :texture_maps        => true,
    #   :triangulated_faces  => true
    # }

    # # XXX Options for hidden geometry and preserve hierarchies?

    # # Try and export the model as a COLLADA file.
    # exported = model.export filename, export_opts

    # # Again, exit if export failed.
    # if not exported
    #   show_wikihouse_error "Couldn't export the model #{model_name}"
    #   dialog.close
    #   return
    # end

  end

  dialog.add_action_callback "uploaded" do |dialog, params|
    if WIKIHOUSE_UPLOADS.key? dialog
      WIKIHOUSE_UPLOADS.delete dialog
    end
    if params == "success"
      UI.messagebox "Successfully uploaded #{model_name}"
    else
      UI.messagebox "Upload to #{WIKIHOUSE_TITLE} failed. Please try again."
    end
    dialog.bring_to_front
  end

  dialog.add_action_callback "download" do |dialog, params|
    wikihouse_download_callback dialog, params
  end

  dialog.add_action_callback "save" do |dialog, download_id|
    wikihouse_save_callback dialog, download_id
  end

  dialog.add_action_callback "error" do |dialog, download_id|
    wikihouse_error_callback dialog, download_id
  end

  # TODO(tav): There can be a situation where the dialog has been closed, but
  # the upload succeeds and the dialog gets called with "uploaded" and brought
  # to front.
  dialog.set_on_close do
    dialog.set_url "about:blank"
    if WIKIHOUSE_UPLOADS.key? dialog
      show_wikihouse_error "Upload to #{WIKIHOUSE_TITLE} has been aborted"
      WIKIHOUSE_UPLOADS.delete dialog
    end
  end

  dialog.set_url WIKIHOUSE_UPLOAD_URL
  dialog.show

end

# ------------------------------------------------------------------------------
# Set Globals
# ------------------------------------------------------------------------------

if not file_loaded? __FILE__

  # Initialise the data containers.
  WIKIHOUSE_DOWNLOADS = Hash.new
  WIKIHOUSE_UPLOADS = Hash.new

  # Initialise the downloads counter.
  $WIKIHOUSE_DOWNLOADS_ID = 0

  # Initialise the core commands.
  WIKIHOUSE_DOWNLOAD = UI::Command.new "Get Models..." do
    load_wikihouse_download
  end

  WIKIHOUSE_DOWNLOAD.tooltip = "Find new models to use at #{WIKIHOUSE_TITLE}"

  # TODO(tav): Irregardless of these procs, all commands seem to get greyed out
  # when no models are open -- at least, on OS X.
  WIKIHOUSE_DOWNLOAD.set_validation_proc {
    MF_ENABLED
  }

  WIKIHOUSE_MAKE = UI::Command.new "Make This House..." do
    load_wikihouse_make
  end

  WIKIHOUSE_MAKE.tooltip = "Convert a model of a House into printable components"
  WIKIHOUSE_MAKE.set_validation_proc {
    if Sketchup.active_model
      MF_ENABLED
    else
      MF_DISABLED|MF_GRAYED
    end
  }

  WIKIHOUSE_UPLOAD = UI::Command.new "Share Model..." do
    load_wikihouse_upload
  end

  WIKIHOUSE_UPLOAD.tooltip = "Upload and share your model at #{WIKIHOUSE_TITLE}"
  WIKIHOUSE_UPLOAD.set_validation_proc {
    if Sketchup.active_model
      MF_ENABLED
    else
      MF_DISABLED|MF_GRAYED
    end
  }

  # Register a new toolbar with the commands.
  WIKIHOUSE_TOOLBAR = UI::Toolbar.new WIKIHOUSE_TITLE
  WIKIHOUSE_TOOLBAR.add_item WIKIHOUSE_DOWNLOAD
  WIKIHOUSE_TOOLBAR.add_item WIKIHOUSE_UPLOAD
  WIKIHOUSE_TOOLBAR.add_item WIKIHOUSE_MAKE
  WIKIHOUSE_TOOLBAR.show

  # Register a new submenu of the standard Plugins menu with the commands.
  WIKIHOUSE_MENU = UI.menu("Plugins").add_submenu WIKIHOUSE_TITLE
  WIKIHOUSE_MENU.add_item WIKIHOUSE_DOWNLOAD
  WIKIHOUSE_MENU.add_item WIKIHOUSE_UPLOAD
  WIKIHOUSE_MENU.add_item WIKIHOUSE_MAKE

  # Add our custom AppObserver.
  Sketchup.add_observer WikiHouseAppObserver.new

  # Display the Ruby Console in dev mode.
  if WIKIHOUSE_DEV
    Sketchup.send_action "showRubyPanel:"
    def w
      load "wikihouse.rb"
    end
    puts ""
    puts "#{WIKIHOUSE_TITLE} Plugin Successfully Loaded."
    puts ""
  end

  file_loaded __FILE__

end

def w
  load "wikihouse.rb"
  puts
  make_wikihouse Sketchup.active_model, true
end
