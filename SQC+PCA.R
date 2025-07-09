rm(list=ls())
# Load libraries
library(caret)
library(ggplot2)
library(dplyr)
library(e1071)
library(naivebayes)
library(kernlab)

# Load and combine data
red <- read.csv("C:\\Users\\DELL\\Desktop\\PROJECT\\wine quality-red.csv")
white <- read.csv("C:\\Users\\DELL\\Desktop\\PROJECT\\winequality-white.csv")


red$color <- "red"
white$color <- "white"
data <- rbind(red, white)

# Convert quality into binary class
data$trans.quality <- ifelse(data$quality < 6, 0, 1)
data$trans.quality <- as.factor(data$trans.quality)
data$color <- as.factor(data$color)
data$quality <- NULL  # remove original

# -------------------------------
# ✨ Step 1: Apply SQC (outlier removal using mean ± 3*SD)
# -------------------------------
numeric_cols <- sapply(data, is.numeric)
for (col in names(data)[numeric_cols]) {
  mean_col <- mean(data[[col]], na.rm = TRUE)
  sd_col <- sd(data[[col]], na.rm = TRUE)
  data <- data[data[[col]] >= (mean_col - 3 * sd_col) & data[[col]] <= (mean_col + 3 * sd_col), ]
}

# -------------------------------
# ✨ Step 2: PCA (Principal Component Analysis)
# -------------------------------
predictors <- setdiff(names(data), "trans.quality")
pre_proc <- preProcess(data[, predictors], method = c("center", "scale", "pca"), pcaComp = 10)
data_pca <- predict(pre_proc, data[, predictors])
data_pca$trans.quality <- data$trans.quality

# -------------------------------
# ✨ Step 3: Train/Test Split
# -------------------------------
set.seed(123)
splitIndex <- createDataPartition(data_pca$trans.quality, p = 0.8, list = FALSE)
train_data <- data_pca[splitIndex, ]
val_data <- data_pca[-splitIndex, ]

# -------------------------------
# ✨ Step 4: Train Models and Report Accuracy
# -------------------------------
models <- list(
  "Logistic Regression" = "glm",
  "Decision Tree" = "rpart",
  "Random Forest" = "rf",
  "KNN" = "knn",
  "Naive Bayes" = "naive_bayes",
  "SVM" = "svmRadial"
)

ctrl <- trainControl(method = "cv", number = 5)
results <- data.frame(Model = character(), Accuracy = numeric(), stringsAsFactors = FALSE)

for (model_name in names(models)) {
  cat("Training", model_name, "...\n")
  
  if (model_name == "KNN") {
    grid <- expand.grid(k = seq(3, 11, 2))
  } else if (model_name == "Random Forest") {
    grid <- expand.grid(mtry = c(2, 4, 6))
  } else {
    grid <- NULL
  }
  
  model <- train(
    trans.quality ~ .,
    data = train_data,
    method = models[[model_name]],
    trControl = ctrl,
    tuneGrid = grid
  )
  
  pred <- predict(model, newdata = val_data)
  acc <- mean(pred == val_data$trans.quality)
  results <- rbind(results, data.frame(Model = model_name, Accuracy = round(acc, 4)))
}

# Show final accuracy results
print(results)




###########################CONFUSION MATRIX##################
library(ggplot2)
library(caret)
library(reshape2)


plot_confusion_matrix <- function(actual, predicted, title = "Confusion Matrix") {
  cm <- confusionMatrix(predicted, actual)
  cm_table <- as.data.frame(cm$table)
  colnames(cm_table) <- c("Prediction", "Reference", "Freq")
  
  ggplot(cm_table, aes(x = Reference, y = Prediction, fill = Freq)) +
    geom_tile(color = "white") +
    geom_text(aes(label = Freq), vjust = 1) +
    scale_fill_gradient(low = "white", high = "steelblue") +
    labs(title = title, x = "Actual", y = "Predicted") +
    theme_minimal()
}


# Store all models and predictions for plotting confusion matrices
model_predictions <- list()

for (model_name in names(models)) {
  cat("Training", model_name, "...\n")
  
  if (model_name == "KNN") {
    grid <- expand.grid(k = seq(3, 11, 2))
  } else if (model_name == "Random Forest") {
    grid <- expand.grid(mtry = c(2, 4, 6))
  } else {
    grid <- NULL
  }
  
  model <- train(
    trans.quality ~ .,
    data = train_data,
    method = models[[model_name]],
    trControl = ctrl,
    tuneGrid = grid
  )
  
  pred <- predict(model, newdata = val_data)
  acc <- mean(pred == val_data$trans.quality)
  results <- rbind(results, data.frame(Model = model_name, Accuracy = round(acc, 4)))
  
  # Store predictions for plotting later
  model_predictions[[model_name]] <- list(pred = pred, model = model)
}

# Plot all confusion matrices
for (model_name in names(model_predictions)) {
  pred <- model_predictions[[model_name]]$pred
  print(plot_confusion_matrix(val_data$trans.quality, pred, paste(model_name, "Confusion Matrix")))
}


