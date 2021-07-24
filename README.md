# CurveTransect

library(devtools)
install_github("esbach/CurveTransect")

# Step 1: Build Sample Transect

# create curving transect
transectXY = data.frame(matrix(nrow=11, ncol=2))
colnames(transectXY) = c("x", "y")
transectXY$x = c(1096002, 1096052, 1096002, 1095952, 1096002, 1096052, 1096002, 1095952, 1096002, 1096052, 1096002)
transectXY$y = c(-39178.7, -39078.7, -38978.7, -38878.7, -38778.7, -38678.7, -38578.7, -38478.7, -38378.7, -38278.7, -38178.7)
transectXY = data.matrix(transectXY)
library(Orcs) #coords2Line
transect = coords2Lines(transectXY, ID="A") # transectXY into line
library(smoothr) #curve smoothing
transect = smooth(transect, method="chaikin") # smooth line

# set crs for transect
projected = CRS("+proj=utm +zone=17 +ellps=intl +units=m +datum=WGS84 +no_defs")
proj4string(transect) = projected

# Step 2: Crete Equally Distanced Points on Transect

# calculate length of transect
library(rgeos) # gLength
length = round(gLength(transect))

# create a data frame with the transect's coordinates
transectXY = data.matrix(transect@lines[[1]]@Lines[[1]]@coords)

# use observerXY function to place spatial points at every meter on transect
transectXY = observerXY(transect=transectXY, spacing=1)

# Step 3: Create some Distance Sampling Data

ds = data.frame("distance"=100, "angle"=90, "meter"=540)

# Step 4: Find Animal Locations

# transform transect and transectXY from utm to latlong
latlong = CRS("+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")
transect = spTransform(transect, latlong)
transectXY = SpatialPoints(transectXY, proj4string=projected)
transectXY = spTransform(transectXY, latlong)

# check to see if first line is the start or the end of meter count
first = SpatialPoints(transectXY, proj4string=latlong)
plot(transect)
points(first[1,], col="red", pch=20)

# convert to data frame
transectXY = data.frame(transectXY@coords)

# add meters colunm in proper order
transectXY$meter = as.numeric(0:length)
transectXY = transectXY[,c(3, 1, 2)]
transectXY = transectXY[order(transectXY$meter), ] # reorder by meter
rownames(transectXY) = transectXY[,1]

# find the spatial location of every object (e.g., animal) 
library(geosphere)
animals = detectionXY(transect=transectXY, detections=ds, buffer=5) 

# turn transectXY into *sp* Spatial Points Data Frame
detections = animals
coordinates(detections) = c("x.obs", "y.obs") 
proj4string(detections) = latlong

meter = transectXY
coordinates(meter) = c("x.obs", "y.obs") 
proj4string(meter) = latlong

# see how it looks
plot(transect)
plot(meter[ds$meter,], col="red", add=T)
plot(detections, pch=20, col="blue", add=T)
