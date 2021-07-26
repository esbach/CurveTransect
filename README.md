# `CurveTransect`
`CurveTransect` is a simple way to facilitate distance sampling on a curving transect. 

Randomly placed, straight line transects can pose many practical challenges. In dense tropical forests, for example, cutting straight-line transects can be time-consuming and expensive, particularly when large areas need to be surveyed. Straight line transects may also cross challenging environments, including rivers, swamps, steep hills, dense vegetation, and more. To overcome these challenges, we present a new method for distance sampling using curving transects within dense forests. This method utilizes standard data collected while conducting a distance sampling analysis (i.e., observer's location on the transect, the distance between the observer and the object, and the angle between the observer and object). This data, along with spatial data for each transect, allows our function to spatially located each object of interest and measure the shortest distance between that object and the transect. The resulting data can be used directly in distance sampling analyses using a package like [Distance](https://github.com/cran/Distance).

## Getting `CurveTransect`

The easiest way to ensure you have the latest version of `CurveTransect`, is to install the `devtools` package:
```
install.packages("devtools")
```
then install `CurveTransect` from github:
```
library(devtools)
install_github("esbach/CurveTransect")
```

## How `CurveTransect` Works

Upon observing an object in the field, staff first record their position to the exact meter on the trail. The monitor then orients themselves along the general bearing of the transect, considering approximately five meters behind and in front of their current position (bearing, *b*). With this bearing, the monitor then records the distance from their current position to the object (*r*), as well as the angle from their bearing to the object (*θ*) with the aid of a 360 degree protractor. 

<img src="https://github.com/esbach/CurveTransect/blob/main/Figures/Figure.jpg" width="500" />

In addition to these data, `CurveTransect` requires a GIS file for each transect. 

From that GIS file, the function ***observerXY*** measures the length of the transect and places points at every meter, recording the coordinates for each. 

Then, for each observation, the function ***objectXY*** locates the meter on the transect where the observation was made and fits a line between that point and five meters before and after (*b*). This fitted line is the bearing, from which the angle (*θ*) and distance (*r*) provided can be used to create geographic coordinates for each detected object’s spatial location. In the final step, the function measures the exact distance between each animal’s location and the nearest point on the transect (*x*). These data are then compiled into a single data-frame that can be directly used for analysis.

## A Sample Analysis

### 1: Create a Transect

here we create a curving transect and smooth the edges
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
projected = CRS("+proj=utm +zone=17 +ellps=intl +units=m +datum=WGS84 +no_defs") # add a crs
proj4string(transect) = projected
```

### 2: Create Equally Distanced Points on Transect

this calculates the length of the transect in meters
```
library(rgeos) # gLength
length = round(gLength(transect))
```

the functions requires a data-frame with two columns containing the x and y coordinates
```
transectXY = data.matrix(transect@lines[[1]]@Lines[[1]]@coords)
```

use ***observerXY*** function to place spatial points at every meter on transect. this function requires two inputs: 
- transectXY is a data-frame with the transects x and y coordinates
- spacing is the spacing between each point placed on the transect in meters (e.g., a point at every meter)
```
transectXY = observerXY(transect=transectXY, spacing=1)
```

### 3: Create some Distance Sampling Data
here we need to provide some sample data collected when conducting a field survey, including:
- distance: number of meters between the observer and the object (e.g., animal) of interest
- angle: degrees (0-360) between the observer's bearing and the object
- meter: the observer's location on the transect
```
ds = data.frame("distance"=100, "angle"=90, "meter"=540)
```

### 4: Find the Spatial Location of Each Object (e.g., an animal)

to find the animal's spatial location, we need to convert our spatial coordinates because dependency functions only work with lat/long coordinates
```
latlong = CRS("+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")
transect = spTransform(transect, latlong)
transectXY = SpatialPoints(transectXY, proj4string=projected)
transectXY = spTransform(transectXY, latlong)
```

- we need to know where the transect starts, so we can put a point at the beginning and switch the order of the meters column as necessary
```
first = SpatialPoints(transectXY, proj4string=latlong)
plot(transect)
points(first[1,], col="red", pch=20)
```
<img src="https://github.com/esbach/CurveTransect/blob/main/Figures/Start.png" width="500" />

convert to data frame
```
transectXY = data.frame(transectXY@coords)
```

add meters colunm in proper order
```
transectXY$meter = as.numeric(0:length)
transectXY = transectXY[,c(3, 1, 2)]
transectXY = transectXY[order(transectXY$meter), ] # reorder by meter
rownames(transectXY) = transectXY[,1]
```

here we use the function ***objectXY*** so spatially locate each animal. this function relies on the following inputs:
- transectXY: a two column data-matrix containing the transect's spatial coordinates
- detections: a data-frame with colums 'meter,' 'distance,' and 'angle'
- buffer: the number of meters betore and after the observer's location used to make bearing on the transect
```
animals = objectXY(transect=transectXY, detections=ds, buffer=5) 
```

turn transectXY into *sp* Spatial Points Data Frame
this turns our data-frame with the distance, meter, angle, and xy coordinates of the object's location into a spatial object for plotting
```
detections = animals
coordinates(detections) = c("x.obs", "y.obs") 
proj4string(detections) = latlong
meter = transectXY
coordinates(meter) = c("x.obs", "y.obs") 
proj4string(meter) = latlong
```

- here we plot the transect, the meter where the observer is located, and the animal's spatial location
```
plot(transect)
plot(meter[ds$meter,], col="red", add=T) # observer location
plot(detections, pch=20, col="blue", add=T) # object location
```
<img src="https://github.com/esbach/CurveTransect/blob/main/Figures/Result.png" width="500" />
