#' Estimates the Bhattacharyya Distance between Two Multivariate Normal
#' Populations
#'
#' For a data matrix, \code{x}, we calculate the Bhattacharyya distance
#' (divergence) between the two classes given in \code{y}.
#'
#' An excellent overview of the Bhattacharyya distance can be found in
#' Fukunaga (1990).
#'
#' @references Fukunaga, Keinosuke (1990). Introduction to Statistical Pattern
#' Recognition. Academic Press Inc., 2nd edition, 1990.
#' \url{http://amzn.to/Ke9m6l}.
#'
#' @export
#' @param x data matrix with \code{n} observations and \code{p} feature vectors
#' @param y class labels for observations (rows) in \code{x}
#' @param diag logical. Should we assume that the covariance matrices are
#' diagonal? If so, this greatly simplifies and expedites the distance
#' calculation
#' @return the estimated Bhattacharyya distance between the two classes given in
#' \code{y}.
bhattacharyya <- function(x, y, diag = FALSE, pool_cov = FALSE, shrink = FALSE) {
  x <- as.matrix(x)
  y <- as.factor(y)

  # Partitions the matrix 'x' into the data for each class.
  class_labels <- levels(y)

  # The calls to 'as.matrix' are to maintain a matrix form if the number of
  # columns of 'x' is 1.
  x1 <- as.matrix(x[which(y == class_labels[1]), ])
  x2 <- as.matrix(x[which(y == class_labels[2]), ])

  # Calculates the MLEs for the population means and diagonal covariance
  # matrices for each class.
  xbar1 <- colMeans(x1)
  xbar2 <- colMeans(x2)
  diff_xbar <- as.vector(xbar1 - xbar2)
  
  # We consider two cases. In the first case the covariance matrices are assumed
  # to be diagonal. This expedites substantially the Bhattacharyya-distance
  # calculation.
  if (diag) {
    if (pool_cov) {
      cov1 <- cov2 <- cov_avg <- diag(cov_pool(x = x, y = y, shrink = shrink))
    } else {
      cov1 <- cov_mle(x1, diag = TRUE, shrink = shrink)
      cov2 <- cov_mle(x2, diag = TRUE, shrink = shrink)
      cov_avg <- (cov1 + cov2) / 2
    }
    
    # Calculates the determinants of the diagonal covariance matrices.
    det_1 <- prod(cov1)
    det_2 <- prod(cov2)
    det_avg <- prod(cov_avg)
  } else {
    if (pool_cov) {
      cov1 <- cov2 <- cov_avg <- cov_pool(x = x, y = y, shrink = shrink)
    } else {
      cov1 <- cov_mle(x1, diag = FALSE, shrink = shrink)
      cov2 <- cov_mle(x2, diag = FALSE, shrink = shrink)
      cov_avg <- (cov1 + cov2) / 2
    }

    # Calculates the determinants of the sample covariance matrices.
    det_1 <- det(cov1)
    det_2 <- det(cov2)
    det_avg <- det(cov_avg)
  }

  # Calculates the estimated Bhattacharyya distance between the two classes.
  distance <- (1/8) * sum(diff_xbar^2 / cov_avg)
  if (!pool_cov) {
    distance <- distance + log(det_avg / sqrt(det_1 * det_2)) / 2
  }
  distance
}

#' Dimension reduction of two simultaneously diagonalized populations based on
#' the Bhattacharyya distance.
#'
#' For a data matrix, \code{x}, we simultaneously diagonalize the two classes
#' given in \code{y}. Then, we calculate the Bhattacharyya distance (divergence)
#' between the two populations for the dimensions ranging from 2 to
#' \code{ncol(x)}.
#'
#' We wish to determine the \code{q} largest Bhattacharyya distances from the
#' \code{p} features in \code{x}. The selected value of \code{q} is the dimension
#' to which the data matrix, \code{x}, is reduced. Notice that our procedure is
#' similar to the reduced dimension selection technique often employed with a
#' scree plot in a Principal Components Analysis (PCA). Our approach generalizes
#' the PCA dimension reduction technique, accordingly.
#'
#' An excellent overview of the Bhattacharyya distance can be found in
#' Fukunaga (1990).
#'
#' We allow shrinkage to be applied to the (diagonal) maximum likelihood
#' estimators (MLEs) for the covariance matrices with the Minimum Distance
#' Empirical Bayes estimator (MDEB) from Srivastava and Kubokawa (2007), which
#' effectively shrinks the MLEs towards an identity matrix that is scaled by the
#' average of the nonzero eigenvalues.
#'
#' @references Fukunaga, Keinosuke (1990). Introduction to Statistical Pattern
#' Recognition. Academic Press Inc., 2nd edition, 1990.
#' \url{http://amzn.to/Ke9m6l}.
#'
#' @references Srivastava, M. S. and Kubokawa, T. (2007). Comparison of
#' discrimination methods for high dimensional data. J. Japan Statist. Soc.,
#' 37(1), 123–134.
#'
#' @export
#' @param x data matrix with \code{n} observations and \code{p} feature vectors
#' @param y class labels for observations (rows) in \code{x}
#' @param q the reduced dimension. By default, \code{q} is determined
#' automatically.
#' @param pct threshold value for the maximum cumulative proportion of
#' the Bhattacharyya distance. We use the threshold to determine the reduced
#' dimension \code{q}. Ignored if \code{q} is specified.
#' @param shrink If \code{TRUE}, we shrink each covariance matrix with the MDEB
#' covariance matrix estimator. Otherwise, no shrinkage is applied.
#' @param tol a value indicating the magnitude below which eigenvalues are
#' considered 0.
#' @return a list containing:
#' \itemize{
#'   \item \code{q}: the reduced dimension determined via \code{bhatta_pct}
#'   \item \code{dist}: the estimated Bhattacharyya distance between the two
#'   classes for each dimension in the transformed space.
#'   \item \code{dist_rank}: the indices of the columns of \code{x} corresponding
#'   to the \code{q} largest Bhattacharyya distances.
#'   \item \code{cumprop}: the cumulative proportion of the sorted Bhattacharyya
#'   distances for each column given in \code{x}.
#' }
bhatta_simdiag <- function(x, y, q = NULL, pct = 0.9, pool_cov = FALSE, shrink = FALSE, tol = 1e-6) {
  simdiag_out <- simdiag_cov(x = x, y = y)

  dist <- sapply(seq_len(ncol(simdiag_out$x)), function(j) {
    bhattacharyya(simdiag_out$x[, j], y, diag = TRUE, pool_cov = pool_cov, shrink = shrink)
  })
  sorted_dist <- sort(dist, decreasing = TRUE)
  cumprop <- cumsum(sorted_dist) / sum(sorted_dist)
  
  # If 'q' is specified, we use it. If it is not given (default), then we select
  # 'q' to be the cumulative proportion less than the percentage specified.
  if (!is.null(q)) {
    q <- as.integer(q)
  } else {
    q <- sum(cumprop <= pct)
  }
  dist_rank <- order(dist, decreasing = TRUE)[seq_len(q)]

  list(q = q, dist = dist, dist_rank = dist_rank, cumprop = cumprop)
}

#' Cross-validation approach to select the optimal reduced dimension
#'
#' TODO
#'
#' @export
#' @param x matrix containing the data. The rows are the observations, and the
#' columns are the features
#' @param y vector of class labels for each observation
#' @param q vector of the reduced dimensions considered. By default, we ... TODO
#'
bhatta_cv <- function(x, y, q = NULL, num_folds = 10, ...) {
  x <- as.matrix(x)
  y <- as.factor(y)
  p <- ncol(x)

  # Partitions the data into the number of folds specified by the user.
  cv_folds <- cv_partition(y = y, num_folds = num_folds)

  # If the candidate values of 'q' are not specified, we determine them
  # automatically to be the minimum value of the class with the maximum sample
  # size across all cross-validation folds.
  if (is.null(q)) {
    q_max <- min(sapply(cv_folds, function(cv_fold) {
      max(table(y[cv_fold$training]))
    }))
    q <- seq.int(2, q_max)
  }
  
  # Traverse through each cross-validation fold and compute the number of
  # cross-validation errors for each reduced dimension
  cv_errors <- lapply(cv_folds, function(cv_fold) {
    trn_x <- x[cv_fold$training, ]
    trn_y <- y[cv_fold$training]
    tst_x <- x[cv_fold$test, ]
    tst_y <- y[cv_fold$test]

    # For each reduced dimension considered, we calculate the number of test errors
    # resulting for the current cross-validation fold.
    cv_num_vars <- sapply(q, function(q_val) {
      # Train the 'simdiag' classifier for the current value of 'q'
      simdiag_out <- simdiag(x = trn_x, y = trn_y, bhattacharyya = TRUE, q = q_val,
                             ...)
    
      # Calculate the number of cv errors from the test data set
      sum(predict(simdiag_out, tst_x)$class != tst_y)
    })
  })
  cv_errors <- colSums(do.call(rbind, cv_errors))

  # Determines the optimal value of 'q' to be the one that yielded the minimized
  # the cross-validation error rate. If there is a tie, we break the tie by
  # choosing the smallest value of 'q' for parsimony.
  q_optimal <- q[which.min(cv_errors)]

  # Updates the cross-validation errors into a data.frame that is easier to
  # follow:
  # For each value of 'q', we record the number of cross-validation errors.
  cv_errors <- cbind.data.frame(q = q, errors = cv_errors)

  list(q = q_optimal, cv_errors = cv_errors)
}
