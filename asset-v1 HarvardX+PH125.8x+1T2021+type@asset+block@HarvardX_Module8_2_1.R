# HarvardX: PH125.8x
# Data Science: Machine Learning
# R code from course videos

# Machine Learning Basics

## Basics of Evaluating Machine Learning Algorithms Comprehension Check

###############################################################################

install.packages('e1071', dependencies=TRUE)




### Caret package, training and test sets, and overall accuracy
library(tidyverse)
library(caret)
library(dslabs)

#### Predict Male ###

#Heights set(dslabs)
data(heights)

# define the outcome and predictors
y <- heights$sex
x <- heights$height

# generate training and test sets
set.seed(2)
test_index <- createDataPartition(y, times = 1, p = 0.5, list = FALSE)

test_set <- heights[test_index, ]
train_set <- heights[-test_index, ]



# guess the outcome
#sample function to compare algorithms
y_hat <- sample(c("Male", "Female"),length(test_index), replace = TRUE)


#factor(operador pipeline %>% es util para concatenar multiples dplyr operaciones)
#caret package, require or recommend that categorical outcomes be coded as factors.
y_hat <- sample(c("Male", "Female"), length(test_index), replace = TRUE) %>% 
     factor(levels = levels(test_set$sex))


#The overall accuracy is simply defined as the overall proportion that is predicted correctly
mean(y_hat == test_set$sex)



#Exploratory data suggests males are slightly taller than females.
heights %>% group_by(sex) %>% summarize(mean(height), sd(height))

#Predict male if height is within two standard deviations from the average male
y_hat <- ifelse(x > 62, "Male", "Female") %>% factor(levels = levels(test_set$sex))

#The overall accuracy
mean(y == y_hat)



#examine accuracy we obtain with 10 different cutoffs and pick the one yielding the best result.
cutoff <- seq(61, 70)
accuracy <- map_dbl(cutoff, function(x){
     y_hat <- ifelse(train_set$height > x, "Male", "Female") %>% 
          factor(levels = levels(test_set$sex))
     mean(y_hat == train_set$sex)
})

#plot showing the accuracy on the training set for males and females.
data.frame(cutoff, accuracy) %>% 
     ggplot(aes(cutoff, accuracy)) + 
     geom_point() + 
     geom_line() 

#max value
max(accuracy)

#Maximized cut-off(best)
best_cutoff <- cutoff[which.max(accuracy)]
best_cutoff


 
#Test cut-off on our test set to make sure accuracy is not overly optimistic.
y_hat <- ifelse(test_set$height > best_cutoff, "Male", "Female") %>% 
     factor(levels = levels(test_set$sex))
y_hat <- factor(y_hat)
mean(y_hat == test_set$sex)

#############################################################################

### Confusion Matrix

#tabulate each combination of prediction and actual value
table(predicted = y_hat, actual = test_set$sex)

#compute the accuracy separately for each sex
test_set %>% 
     mutate(y_hat = y_hat) %>%
     group_by(sex) %>% 
     summarize(accuracy = mean(y_hat == sex))

# Male percentage(prevalence)
prev <- mean(y == "Male")
prev

#Confusion matrix representation
mat <- matrix(c("True positives (TP)", "False negatives (FN)", 
                "False positives (FP)", "True negatives (TN)"), 2, 2)
colnames(mat) <- c("Actually Positive", "Actually Negative")
rownames(mat) <- c("Predicted positve", "Predicted negative")
as.data.frame(mat) %>% knitr::kable()

#Confusion matrix function
confusionMatrix(data = y_hat, reference = test_set$sex)



####################################################################################

### Balanced accuracy and F1 score

# maximize F-score instead of overall accuracy.
#F_meas function in the caret package computes the summary with beta defaulting to one.
cutoff <- seq(61, 70)
F_1 <- map_dbl(cutoff, function(x){
     y_hat <- ifelse(train_set$height > x, "Male", "Female") %>% 
          factor(levels = levels(test_set$sex))
     F_meas(data = y_hat, reference = factor(train_set$sex))
})

#plot the F1 measure versus the different cutoffs.
data.frame(cutoff, F_1) %>% 
     ggplot(aes(cutoff, F_1)) + 
     geom_point() + 
     geom_line()

max(F_1)

#maximized when we use a cutoff of 66 inches.
best_cutoff <- cutoff[which.max(F_1)]
best_cutoff

#cutoff balances the specificity and sensitivity of our confusion matrix
y_hat <- ifelse(test_set$height > best_cutoff, "Male", "Female") %>% 
     factor(levels = levels(test_set$sex))
confusionMatrix(data = y_hat, reference = test_set$sex)

#######################################################################################

### Prevalence matters in practice

### ROC and precision-recall curves

#guessing male with higher probability would give us higher accuracy due to the bias in the sample
#predicts male guessing 90% of the time, this would come at a cost of lower sensitivity
p <- 0.9
y_hat <- sample(c("Male", "Female"), length(test_index), replace = TRUE, prob=c(p, 1-p)) %>% 
     factor(levels = levels(test_set$sex))
mean(y_hat == test_set$sex)

#ROC curve for guessing sex, but using different probabilities of guessing male
#ROC curve for guessing always looks like this, like the identity line
#a perfect algorithm would shoot straight to one and stay up there, perfect sensitivity for all values of specificity
probs <- seq(0, 1, length.out = 10)
guessing <- map_df(probs, function(p){
     y_hat <- 
          sample(c("Male", "Female"), length(test_index), replace = TRUE, prob=c(p, 1-p)) %>% 
          factor(levels = c("Female", "Male"))
     list(method = "Guessing",
          FPR = 1 - specificity(y_hat, test_set$sex),
          TPR = sensitivity(y_hat, test_set$sex))
})
guessing %>% qplot(FPR, TPR, data =., xlab = "1 - Specificity", ylab = "Sensitivity")


#construct an ROC curve for the height-based approach
cutoffs <- c(50, seq(60, 75), 80)
height_cutoff <- map_df(cutoffs, function(x){
     y_hat <- ifelse(test_set$height > x, "Male", "Female") %>% 
          factor(levels = c("Female", "Male"))
     list(method = "Height cutoff",
          FPR = 1-specificity(y_hat, test_set$sex),
          TPR = sensitivity(y_hat, test_set$sex))
})

# plotting both curves together, we are able to compare sensitivity for different values of specificity
# we obtain higher sensitivity with the height-based approach for all values of specificity, which imply it is a better method
bind_rows(guessing, height_cutoff) %>%
     ggplot(aes(FPR, TPR, color = method)) +
     geom_line() +
     geom_point() +
     xlab("1 - Specificity") +
     ylab("Sensitivity")

#when making ROC curves, it is often nice to add the cutoff used to the points.
map_df(cutoffs, function(x){
     y_hat <- ifelse(test_set$height > x, "Male", "Female") %>% 
          factor(levels = c("Female", "Male"))
     list(method = "Height cutoff",
          cutoff = x, 
          FPR = 1-specificity(y_hat, test_set$sex),
          TPR = sensitivity(y_hat, test_set$sex))
}) %>%
     ggplot(aes(FPR, TPR, label = cutoff)) +
     geom_line() +
     geom_point() +
     geom_text(nudge_y = 0.01)

#when prevalence matters, we make a precision recall plot, plotting precision against recall.
#Guess
guessing <- map_df(probs, function(p){
     y_hat <- sample(c("Male", "Female"), length(test_index), 
                     replace = TRUE, prob=c(p, 1-p)) %>% 
          factor(levels = c("Female", "Male"))
     list(method = "Guess",
          recall = sensitivity(y_hat, test_set$sex),
          precision = precision(y_hat, test_set$sex))
})
#Cutoff
height_cutoff <- map_df(cutoffs, function(x){
     y_hat <- ifelse(test_set$height > x, "Male", "Female") %>% 
          factor(levels = c("Female", "Male"))
     list(method = "Height cutoff",
          recall = sensitivity(y_hat, test_set$sex),
          precision = precision(y_hat, test_set$sex))
})
#Plot
#precision of guessing is not high.This is because the prevalence is low
bind_rows(guessing, height_cutoff) %>%
     ggplot(aes(recall, precision, color = method)) +
     geom_line() +
     geom_point()


#change positives to mean male instead of females
#Guess
guessing <- map_df(probs, function(p){
     y_hat <- sample(c("Male", "Female"), length(test_index), replace = TRUE, 
                     prob=c(p, 1-p)) %>% 
          factor(levels = c("Male", "Female"))
     list(method = "Guess",
          recall = sensitivity(y_hat, relevel(test_set$sex, "Male", "Female")),
          precision = precision(y_hat, relevel(test_set$sex, "Male", "Female")))
})
#Cutoff
height_cutoff <- map_df(cutoffs, function(x){
     y_hat <- ifelse(test_set$height > x, "Male", "Female") %>% 
          factor(levels = c("Male", "Female"))
     list(method = "Height cutoff",
          recall = sensitivity(y_hat, relevel(test_set$sex, "Male", "Female")),
          precision = precision(y_hat, relevel(test_set$sex, "Male", "Female")))
})
#Plot
#ROC curve remains the same, but the precision recall plot changes
bind_rows(guessing, height_cutoff) %>%
     ggplot(aes(recall, precision, color = method)) +
     geom_line() +
     geom_point()
