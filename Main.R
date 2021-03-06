# Jeroen Roelofs
# 15-1-2015

# Load libraries.
library(raster)
library(sp)
library(downloader)
library(rasterVis)

# Create data folder.
dir.create("./Data")

# Download data from site
download('https://github.com/GeoScripting-WUR/AdvancedRasterAnalysis/raw/gh-pages/data/GewataB1.rda', 'Data/GewataB1.rda', quiet = T, mode = "wb")
download('https://github.com/GeoScripting-WUR/AdvancedRasterAnalysis/raw/gh-pages/data/GewataB2.rda', 'Data/GewataB2.rda', quiet = T, mode = "wb")
download('https://github.com/GeoScripting-WUR/AdvancedRasterAnalysis/raw/gh-pages/data/GewataB3.rda', 'Data/GewataB3.rda', quiet = T, mode = "wb")
download('https://github.com/GeoScripting-WUR/AdvancedRasterAnalysis/raw/gh-pages/data/GewataB4.rda', 'Data/GewataB4.rda', quiet = T, mode = "wb")
download('https://github.com/GeoScripting-WUR/AdvancedRasterAnalysis/raw/gh-pages/data/GewataB5.rda', 'Data/GewataB5.rda', quiet = T, mode = "wb")
download('https://github.com/GeoScripting-WUR/AdvancedRasterAnalysis/raw/gh-pages/data/GewataB7.rda', 'Data/GewataB7.rda', quiet = T, mode = "wb")
download('https://github.com/GeoScripting-WUR/AdvancedRasterAnalysis/raw/gh-pages/data/vcfGewata.rda', 'Data/vcfGewata.rda', quiet = T, mode = "wb")
download('https://github.com/GeoScripting-WUR/AdvancedRasterAnalysis/raw/gh-pages/data/trainingPoly.rda', 'Data/trainingPoly.rda', quiet = T, mode = "wb")

# Load data.
load("Data/GewataB1.rda")
load("Data/GewataB2.rda")
load("Data/GewataB3.rda")
load("Data/GewataB4.rda")
load("Data/GewataB5.rda")
load("Data/GewataB7.rda")
load("Data/trainingPoly.rda")
load("Data/vcfGewata.rda")

# Brick raster.
gewata <- brick(GewataB1, GewataB2, GewataB3, GewataB4, GewataB5, GewataB7)

# Check data visual.
#plot(gewata)
#hist(gewata)
#pairs(gewata)

# Band 4 is the least correlated and will be removed from the model calculation

# Remove NA from vcf data
vcfGewata[vcfGewata > 100] <- NA

NDVI <- overlay(GewataB4, GewataB3, fun = function (x,y){(x-y) /(x+y)})
# plot(NDVI)

# Columns and pairscheck
covs <- addLayer(gewata,vcfGewata,NDVI)
covs <- dropLayer(covs,"gewataB4")
names(covs) <- c("band1","band2","band3","band5","band7","vcf","NDVI")
#pairs(covs, progress="text")

# Produce one or more plots that demonstrate the relationship between the Landsat bands and the VCF tree cover. What can you conclude from this/these plot(s)?
# You could conclude that form these all bands are likely predictors for the linear model. With band 7 which has the highest correlation, after this band 3, band 5, band 2 and band 1.

# Create a liniear model of the model object.
trainingPoly@data$Code <- as.numeric(trainingPoly@data$Class)
# trainingPoly@data
classes <- rasterize(trainingPoly, NDVI, field='Code')

cols <- c("orange", "dark green", "light blue")
plot(classes, col=cols, legend=FALSE)
legend("topright", legend=c("cropland", "forest", "wetland"), fill=cols, bg="white")

# Combine this new brick with the classes layer.
names(classes) <- "class"
covmasked <- mask(covs, classes)
trainingbrick <- addLayer(covmasked, classes)
plot(trainingbrick)

# Creating a data frame.

valuetable1 <- getValues(trainingbrick)
valuetable1 <- na.omit(valuetable1)
df2 <- as.data.frame(valuetable1)
head(df2, n = 10)

# Linear model for masking areas.
lm_mask <- lm(formula = vcf ~ band1 + band2 + band3 + band5 + band7 + NDVI, data = df2)

# Create raster based on masked linear model.
Prediction_vcf_mask <- predict(trainingbrick, lm_mask, filename = "data/prediction_raster_mask", progress = "text", overwrite = TRUE, na.rm = TRUE)
Prediction_vcf_mask[Prediction_vcf_mask < 0] <- NA
Prediction_vcf_mask@data@values[Prediction_vcf_mask@data@values < 0] <- 0
Prediction_vcf_mask@data@values[Prediction_vcf_mask@data@values > 100] <- 100

# Predicted values.
Difference <- Prediction_vcf_mask - vcfGewata
parplot <- par(mfrow=c(1,3))

# Plot models.
plot(Prediction_vcf_mask, zlim = c(0,100), main = "Prediction Model")
plot(vcfGewata, main = "VCF Model")
plot(Difference, zlim = c(0, 60), main = "Difference Predicted VS. VCF Model")
par(parplot)

RMSE = sqrt(mean((Prediction_vcf_mask@data@values - covs$vcf@data@values)^2, na.rm = TRUE))
sprintf('The RMSE is %f', RMSE)
# [1] "The RMSE is 7.092230"

# RMSE variables for polygon areas.
y_pred <- Prediction_vcf_mask
y <- vcfGewata
x <- (y-y_pred)^2
z <- zonal(x, classes, fun='mean', digits=0, na.rm=TRUE)
RMSE2 <- sqrt(z[,2])
RMSE2
# RMSE class 1: 7.993166
# RMSE class 2: 4.690525
# RMSE class 3: 8.726209
