# CurveTransect
a package to support distance sampling on a curving transect

## Step 1: Install and/or Load the CurveTransect Package
```
library(devtools)
install_github("esbach/CurveTransect")
```

## Step 2: Build Sample Transect

- ### create curving transect
- here we create a curving transect and smooth the edges
```
transectXY = data.frame(matrix(nrow=11, ncol=2))
colnames(transectXY) = c("x", "y")
transectXY$x = c(1096002, 1096052, 1096002, 1095952, 1096002, 1096052, 1096002, 1095952, 1096002, 1096052, 1096002)
transectXY$y = c(-39178.7, -39078.7, -38978.7, -38878.7, -38778.7, -38678.7, -38578.7, -38478.7, -38378.7, -38278.7, -38178.7)
transectXY = data.matrix(transectXY)
library(Orcs) #coords2Line
transect = coords2Lines(transectXY, ID="A") # transectXY into line
library(smoothr) #curve smoothing
transect = smooth(transect, method="chaikin") # smooth line
```

- ### set crs for transect
- the transect needs a coordinate reference system
```
projected = CRS("+proj=utm +zone=17 +ellps=intl +units=m +datum=WGS84 +no_defs")
proj4string(transect) = projected
```

## Step 2: Crete Equally Distanced Points on Transect

- ### calculate length of transect
- this calculates the length of the transect in meters
```
library(rgeos) # gLength
length = round(gLength(transect))
```

- ### create a data frame with the transect's coordinates
- the functions requires a data-frame with two columns containing the x and y coordinates
```
transectXY = data.matrix(transect@lines[[1]]@Lines[[1]]@coords)
```

- ### use observerXY function to place spatial points at every meter on transect
- this function requires two inputs: 
- transectXY is a data-frame with the transects x and y coordinates
- spacing is the spacing between each point placed on the transect in meters (e.g., a point at every meter)
```
transectXY = observerXY(transect=transectXY, spacing=1)
```

## Step 3: Create some Distance Sampling Data
- data collected when conducting a field survey
- distance equals the number of meters between the observer and the object (e.g., animal) of interest
- angle is the degrees (0-360) between the observer's bearing and the object
- meter is the observer's location on the transect
```
ds = data.frame("distance"=100, "angle"=90, "meter"=540)
```

## Step 4: Find Animal Locations

- ### transform transect and transectXY from utm to latlong
- to find the animal's spatial location, we need to convert our spatial coordinates
- we do this because dependency functions only work with lat/long coordinates
```
latlong = CRS("+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")
transect = spTransform(transect, latlong)
transectXY = SpatialPoints(transectXY, proj4string=projected)
transectXY = spTransform(transectXY, latlong)
```

- ### check to see if first line is the start or the end of meter count
- we need to know where the transect starts, so we can put a poitn at the beginning and switch the order if necessary
```
first = SpatialPoints(transectXY, proj4string=latlong)
plot(transect)
points(first[1,], col="red", pch=20)
```

- ### convert to data frame
```
transectXY = data.frame(transectXY@coords)
```

- ### add meters colunm in proper order
```
transectXY$meter = as.numeric(0:length)
transectXY = transectXY[,c(3, 1, 2)]
transectXY = transectXY[order(transectXY$meter), ] # reorder by meter
rownames(transectXY) = transectXY[,1]
```

- ### find the spatial location of every object (e.g., animal) 
- here we use the function "detectionXY" so spatially locate each animal
- this function relies on the following inputs:
- transectXY: a two column data-matrix containing the transect's spatial coordinates
- detections: a data-frame with colums 'meter,' 'distance,' and 'angle'
- buffer: the number of meters betore and after the observer's location used to make bearing on the transect
```
library(geosphere)
animals = detectionXY(transect=transectXY, detections=ds, buffer=5) 
```

- ### turn transectXY into *sp* Spatial Points Data Frame
- this turns our data-frame with the distance, meter, angle, and xy coordinates of the object's location into a spatial object for plotting
```
detections = animals
coordinates(detections) = c("x.obs", "y.obs") 
proj4string(detections) = latlong
meter = transectXY
coordinates(meter) = c("x.obs", "y.obs") 
proj4string(meter) = latlong
```

- ### see how it looks
- here we plot the transect, the meter where the observer is located, and the animal's spatial location
```
plot(transect)
plot(meter[ds$meter,], col="red", add=T)
plot(detections, pch=20, col="blue", add=T)
```
