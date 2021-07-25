# `CurveTransect`
`CurveTransect` is a simple way to facilitate distance sampling on a curving transect. 

Randomly placed, straight line transects can pose many practical challenges. In dense tropical forests, for example, cutting straight-line transects can be time-consuming and expensive, particularly when large areas need to be surveyed. Straight line transects may also cross challenging environments, including rivers, swamps, steep hills, dense vegetation, and more. To overcome these challenges, we suggest a new method for distance sampling using curving transects within dense forests. Field staff can use straight line transects randomly generated through geographic information systems (GIS) as a guide, making adjustments when clearing actual paths through dense forests to facilitate safety and sidestep challenging areas. This method maintains overall randomness and simultaneously improves working conditions by allowing staff to walk adjacent to, rather than directly through, dangerous environments. Such transects not only support a safe working environment but can improve detectability.

We developed a method to support accurate distance sampling on curving transects. Upon observing an object in the field, staff first record their position to the exact meter on the trail. The monitor then orients themselves along the general bearing of the transect, considering approximately five meters behind and in front of their current position (this distance can be modified). With this bearing, the monitor then records the distance from their current position to the object, as well as the angle from their bearing to the object with the aid of a 360 degree protractor.

After these data have been transferred to an electronic format, they can be imported into R, where a the function found here measures the nearest distance between the object and the curving transect. The function requires various inputs: (1) a GIS file for each transect, (2) the meter location of the observer when they encountered an object, (3) the angle between the object and the observer’s bearing, and (4) the distance between the animal and the observer. With the GIS file of the transect, the function first measures the length of the transect, then places a point at each meter, recording the coordinates for each. Then, for each observation, it locates the meter on the transect where the observation was made and fits a line between that point and five meters before and after. This fitted line is the bearing, from which the angle and distance provided can be used to create geographic coordinates for each detected object’s spatial location. In the final step, the function measures the exact distance between each animal’s location and the nearest point on the transect. These data are then compiled into a single data-frame that can be directly used for analysis (i.e., with the package [Distance] (https://github.com/cran/Distance/blob/master/README.md)




## Getting `CurveTransect`

The easiest way to ensure you have the latest version of `CurveTransect`, is to install the `devtools` package:

      install.packages("devtools")

then install `CurveTransect` from github:

      library(devtools)
      install_github("esbach/CurveTransect")
      
## How `CurveTransect` Works

### 1: Install and/or Load the CurveTransect Package
```
library(devtools)
install_github("esbach/CurveTransect")
```

### 2: Build Sample Transect

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

- the transect needs a coordinate reference system (crs)
```
projected = CRS("+proj=utm +zone=17 +ellps=intl +units=m +datum=WGS84 +no_defs")
proj4string(transect) = projected
```

### 2: Crete Equally Distanced Points on Transect

- this calculates the length of the transect in meters
```
library(rgeos) # gLength
length = round(gLength(transect))
```

- create a data frame with the transect's coordinates
- the functions requires a data-frame with two columns containing the x and y coordinates
```
transectXY = data.matrix(transect@lines[[1]]@Lines[[1]]@coords)
```

- use observerXY function to place spatial points at every meter on transect
- this function requires two inputs: 
- transectXY is a data-frame with the transects x and y coordinates
- spacing is the spacing between each point placed on the transect in meters (e.g., a point at every meter)
```
transectXY = observerXY(transect=transectXY, spacing=1)
```

### 3: Create some Distance Sampling Data
- data collected when conducting a field survey
- distance equals the number of meters between the observer and the object (e.g., animal) of interest
- angle is the degrees (0-360) between the observer's bearing and the object
- meter is the observer's location on the transect
```
ds = data.frame("distance"=100, "angle"=90, "meter"=540)
```

### 4: Find Animal Locations

- to find the animal's spatial location, we need to convert our spatial coordinates
- we do this because dependency functions only work with lat/long coordinates
```
latlong = CRS("+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")
transect = spTransform(transect, latlong)
transectXY = SpatialPoints(transectXY, proj4string=projected)
transectXY = spTransform(transectXY, latlong)
```

- check to see if first line is the start or the end of meter count
- we need to know where the transect starts, so we can put a poitn at the beginning and switch the order if necessary
```
first = SpatialPoints(transectXY, proj4string=latlong)
plot(transect)
points(first[1,], col="red", pch=20)
```

- convert to data frame
```
transectXY = data.frame(transectXY@coords)
```

- add meters colunm in proper order
```
transectXY$meter = as.numeric(0:length)
transectXY = transectXY[,c(3, 1, 2)]
transectXY = transectXY[order(transectXY$meter), ] # reorder by meter
rownames(transectXY) = transectXY[,1]
```

- here we use the function "detectionXY" so spatially locate each animal
- this function relies on the following inputs:
- transectXY: a two column data-matrix containing the transect's spatial coordinates
- detections: a data-frame with colums 'meter,' 'distance,' and 'angle'
- buffer: the number of meters betore and after the observer's location used to make bearing on the transect
```
library(geosphere)
animals = detectionXY(transect=transectXY, detections=ds, buffer=5) 
```

- turn transectXY into *sp* Spatial Points Data Frame
- this turns our data-frame with the distance, meter, angle, and xy coordinates of the object's location into a spatial object for plotting
```
detections = animals
coordinates(detections) = c("x.obs", "y.obs") 
proj4string(detections) = latlong
meter = transectXY
coordinates(meter) = c("x.obs", "y.obs") 
proj4string(meter) = latlong
```

- see how it looks
- here we plot the transect, the meter where the observer is located, and the animal's spatial location
```
plot(transect)
plot(meter[ds$meter,], col="red", add=T)
plot(detections, pch=20, col="blue", add=T)
```
