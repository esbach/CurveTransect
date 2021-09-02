# ---------------------------------------#

vector <- function(x) sqrt(sum(x^2))
point <- function(start, first, dist) { 
  # finds point at distance from start point in direction of first point
  v = first - start
  u = v / vector(v)
  return (start + u * dist)
}

#' @title Equidistant Points on Transect
#' @description This function takes a GIS file of a transect and places a point at every meter (or every x meters depending not the spacing you choose). It returns a data-frame with xy coordinates for each meter.
#' @param transectXY Two column data-matrix containing the transect's spatial coordinates
#' @param spacing Numeric spacing (in meters) between each point on the transect
#' @return Data-frame with spatial coordinates for each specified point on the transect
#' @examples 
#' observerXY(transect=transectXY, spacing=1)
#' @export
observerXY <- function(transect, spacing) {
  transectXY = data.matrix(transect@lines[[1]]@Lines[[1]]@coords)
  result = transectXY[1,,drop=FALSE] 
  equidistantPoints = transectXY[1,,drop=FALSE] 
  transectXY = tail(transectXY, n = -1)
  accDist = 0
  while (length(transectXY) > 0) {
    point = transectXY[1,]
    lastPoint = result[1,]
    dist = vector(point - lastPoint)    
    if ( accDist + dist > spacing ) {
      np = new_point(lastPoint, point, spacing - accDist)
      equidistantPoints = rbind(np, equidistantPoints)
      result = rbind(np, result)
      accDist = 0 
    } else {
      transectXY = tail(transectXY, n = -1)
      result = rbind(point, result)    
      accDist = accDist + dist
    }
  }
  observerXY = data.frame(x.obs=equidistantPoints[,1], y.obs=equidistantPoints[,2])
  return(observerXY)
}

# ---------------------------------------#

#' @title Adjusted Transect Length
#' @description Popular distance sampling packages automatically calculate the area covered in the survey based on a straight line, L x 2w, where L is the length of the transect and w is the truncation distance. This function calculates the the area covered in a curved transect and provides and adjusted transect length: curved covered area ÷ (2 × w). When input into popular distance sampling packages, this adjusted length will give the proper covered area. 
#' @param transect GIS file of the transect of class SpatialLines
#' @param trunc Truncation distance (meters)
#' @return Length of the transect (meters) used by distance sampling packages to correctly calculate the covered area. 
#' @examples 
#' adjustedL(transect=transect, trunc=100)
#' @export
adjustedL <- function(transect, trunc) {
  buffer = gBuffer(transect, width = trunc, capStyle = "FLAT")
  area = gArea(buffer, byid=FALSE)
  length = (area)/(2*trunc) / 1000 # meters
}

# ---------------------------------------#

#' @title Spatial Location of Detected Objects
#' @description This function uses the xy coordinates of a transect to locate an observer’s location and calculate their bearing (based on the buffer distance). Using the provided distance (between the observer and the object) and angle, it then spatially locates each detected object. It returns a data frame with xy coordinates for each detection.
#' @param transectXY Two column data-matrix containing the transect's spatial coordinates
#' @param detections Data frame with colums 'meter,' 'distance,' and 'angle.'
#' @param buffer Number of meters around the observer's location used to make bearing on the transect. 
#' @return Data-frame with the animal's spatial location as xy coordinates, plus the original 'meter', 'distance,' and 'angle.' 
#' @examples 
#' objectXY(transect=transectXY, detections=ds, buffer=5) 
#' @export
objectXY <- function(transectXY, detections, buffer){
  # location used to create a bearing line
  detections$x.obs <- detections$y.obs <- rep(0, length(detections$meter))
  for(ii in 1:length(detections$meter)){
    out.temp <- animalXY(meter= detections$meter[ii], distance= detections$distance[ii],  angle= detections$angle[ii], transectXY =transectXY, buffer= buffer)
    detections$x.obs[ii] <- out.temp[1]
    detections$y.obs[ii] <- out.temp[2]
  }
  return(detections)
}

animalXY <- function(meter, distance, angle, transectXY, buffer){
  # takes "meter", "distance", and "angle" from objectXY function
  # transectXY is a dataframe of transect coordinates
  # buffer is the meters from observer's location to create bearing
  local.data <- transectXY[(transectXY[,1] < meter + buffer) & (transectXY[,1] > meter - buffer ),]
   if(nrow(local.data) > 1){
    if(sd(local.data$x) < 1e-4){
      bears <- diag(2)
      bears[,1] <- local.data$x[c(1, length(local.data$x))]
      bears[,2] <- local.data$y[c(1, length(local.data$y))]
      local.line.bear <- bearing(bears[1,], bears[2,])
    } else{
        tt <-lm(local.data$y~local.data$x)
        bears <- diag(2)
        # find the bearing of the line using meter location and buffer
        if (sd(local.data$x) >= sd(local.data$y)){
        bears[,1] <- local.data$x[floor(c(.25, .75) * length(local.data$x))]
        bears[,2] <- tt$coef[1] + tt$coef[2] * bears[,1]
        }else{
        bears[,2] <- local.data$y[floor(c(.25, .75) * length(local.data$y))]
        bears[,1] <- (bears[,2]-tt$coef[1]) / tt$coef[2]
        }
        # bearing from observer location to object
        # assumes meters in transectXY increases as we move down data matrix 
        # the first row ismeter 0 
        local.line.bear <- bearing(bears[1,], bears[2,])
        local.line.bear = (local.line.bear + 360) %% 360
    }
    init.pt <- transectXY[ transectXY[,1]==meter,2:3]
    # angle is measured clockwise (from 0-360)
    final.pt <- destPoint(init.pt, local.line.bear + angle, distance)
    return(final.pt)
  } else{ 
      warning("There are meters outside the trail. Check 'meter' column in 'detections.'")
      return(c(0,0))
  }
}

# ---------------------------------------#

#' @title Curving Transect Distance Measurement
#' @description This function uses the output of “objectXY” (xy coordinates of each detected object) and a GIS file of the transect to measure the nearest distance between each object and the curved transect. It returns a data-frame of distances (x) that can be used in distance sampling analyses.
#' @param detections Output of "objectXY": data-frame with the animal's spatial location as xy coordinates, which must be labelled: "x.obs", "y.obs"
#' @param transect GIS file of the transect of class SpatialLines
#' @return Data-frame with measures of distance (meters) between each detection and the nearest location on the transect
#' @examples 
#' nearest.distance(detections = detections, transect = transect)
#' @export
nearestX <- function(detections, transect) {
  coordinates(detections) = c("x.obs", "y.obs")
  distance = data.frame(dist2Line(detections, transect, distfun=distGeo))
  distance = distance[,1]
  colnames(distance) = c("distance")
  return(distance)
}
