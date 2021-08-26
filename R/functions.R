# ---------------------------------------#

norm_vec <- function(x) sqrt(sum(x^2))
new_point <- function(p0, p1, di) { 
  # finds point in distance di from point p0 in direction of point p1
  v = p1 - p0
  u = v / norm_vec(v)
  return (p0 + u * di)
}

#' Equidistant Points on Transect
#' 
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
    dist = norm_vec(point - lastPoint)    
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

#' Adjusted Transect Length for Curved Covered Area Calculation
#' 
#' @param transect GIS file of the transect of class SpatialLines
#' @param trunc Truncation distance (meters)
#' @return Length of the transect (meters) used by distance sampling packages to correctly calculate the covered area. 
#' @examples 
#' cca(transect=transect, trunc=100)
#' @export
cca <- function(transect, trunc) {
  buffer = gBuffer(transect, width = trunc, capStyle = "FLAT")
  area = gArea(buffer, byid=FALSE)
  length = (area)/(2*trunc) / 1000 # meters
}

# ---------------------------------------#

#' Location of Detected Objects
#' 
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
