besselI(1,c(NA,1))
besselI(c(1,2),1)
besselI(c(1,2,3),c(1,2))
besselI(c(1,2,3),c(1,2),c(3,4,5,6,7,8))
besselI(c(1,NA),1)
besselI(c(1,2,3),c(NA,2))
besselI(c(1,2,3),c(1,2),c(3,4,NA,6,7,8))
argv <- list(FALSE, FALSE, 1); .Internal(besselI(argv[[1]], argv[[2]], argv[[3]]))
argv <- list(logical(0), logical(0), 1); .Internal(besselI(argv[[1]], argv[[2]], argv[[3]]))
