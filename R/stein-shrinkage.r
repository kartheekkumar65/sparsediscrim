# This function computes the function h_{nu, p}(t) on page 1023 of Pang et al. (2009).
# nu is a specified constant (nu = N - K)
# p is the feature space dimension.
# t is a constant specified by the user. By default, t = -1 in Pang et al. (2009).
h <- function(nu, p, t = -1) {
	(nu / 2)^t * (gamma(nu / 2) / gamma(nu / 2 + t / p))^p
}

# This function finds the value for alpha \in [0,1] that empirically minimizes the
# average risk under a Stein loss function, which is given on page 1023 of Pang et al. (2009).
# N is the sample size.
# K is the number of classes.
# var.feature is a vector of the sample variances for each dimension.
# Returns:
#	alpha: the alpha that minimizes the average risk under a Stein loss function.
#		If the minimum is not unique, we randomly select an alpha from the minimizers.
#	risk: the minimum average risk attained.
risk.stein <- function(N, K, var.feature, num.alphas = 2, t = -1) {
	nu <- N - K
	p <- length(var.feature)
	alpha <- seq(0, 1, length = num.alphas)
	
	# The pooled variance is defined in Pang et al. (2009) as the geometric mean
	# of the sample variances of each feature.
	var.pooled <- prod(var.feature)^(1 / p)
	
	# Here we compute the average risk for the Stein loss function on page 1023
	# for all values of alpha.
	risk <- h(nu = nu, p = p)^alpha * h(nu = nu, p = 1)^(1 - alpha)
	risk <- risk / (h(nu = nu, p = 1, t = alpha * t / p))^(p - 1)
	risk <- risk / h(nu = nu, p = 1, t = (1 - alpha + alpha / p) * t)
	risk <- risk * (var.pooled)^(alpha * t)
	risk <- risk * mean(var.feature^(-alpha * t))
	risk <- risk - log(h(nu = nu, p = p)^alpha * h(nu = nu, p = 1)^(1 - alpha))
	risk <- risk - t * digamma(nu / 2)
	risk <- risk + t * log(nu / 2) - 1
	
	# Next we determine the minimum risk attained.
	min.risk <- min(risk)
	
	# Which of the alphas empirically minimize this risk?
	# If there are ties in the minimum risk, we randomly select
	# the value of alpha from the minimizers.
	alpha.min.risk <- alpha[which(min.risk == risk)]
	alpha.star <- sample(alpha.min.risk, 1)
	
	list(alpha = alpha.star, risk = risk[alpha.star], var.pooled = var.pooled)
}

# This function computes the shrinkage-based estimator of variance of each feature (variable)
# from Pang et al. (2009) for the SDLDA classifier.
# N is the sample size.
# K is the number of classes.
# var.feature is a vector of the sample variances for each feature.
# Returns:
#	var.feature.shrink: a vector of the shrunken variances for each feature.
var.shrinkage <- function(N, K, var.feature, num.alphas = 2, t = -1) {
	nu <- N - K
	p <- length(var.feature)
	
	risk.stein.out <- risk.stein(N = N, K = K, var.feature = var.feature, num.alphas = num.alphas, t = t)
	var.pooled <- risk.stein.out$var.pooled
	alpha <- risk.stein.out$alpha
	
	var.feature.shrink <- h(nu = nu, p = p, t = t)^alpha * (h(nu = nu, p = 1, t = t) * var.pooled)^(1 - alpha)
	var.feature.shrink
}