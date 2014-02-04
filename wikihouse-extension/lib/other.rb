
# ------------------------------------------------------------------------------
# Centroid Calculation
# ------------------------------------------------------------------------------

# (Chris) Dont think this function is currently being used 

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

    max = (ax + bx) / 2
    mbx = (bx + cx) / 2
    mcx = (cx + ax) / 2
    may = (ay + by) / 2
    mby = (by + cy) / 2
    mcy = (cy + ay) / 2

    px = ((max * la) + (mbx * lb) + (mcx * lc)) / (la + lb + lc)
    py = ((may * la) + (mby * lb) + (mcy * lc)) / (la + lb + lc)

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
