Rtsne.defaults <- list(
  dims = 2,
  perplexity = 30,
  theta = 0.5,
  max_iter = 1000,
  verbose = getOption("verbose", FALSE),
  Y_init = NULL,
  momentum = 0.5,
  final_momentum = 0.8,
  eta = 200,
  exaggeration_factor = 12,
  num_threads = 1
)
class(Rtsne.defaults) <- "Rtsne.config"

MDS.defaults <- list(
  dims = 2
)
class(MDS.defaults) <- "MDS.config"

print.Rtsne.config <- function(x, ...) {
  if (!is(x, "Rtsne.config")) {
    umap.error("x is not a Rtsne configuration object")
  }
  
  # produce a string of form "  z:  " of total length width
  padspaces <- function(z, width=24) {
    padleft <- max(0, width-nchar(z)-2)
    paste(c(rep(" ", padleft), z, ": "), collapse="")
  }
  
  message("Rtsne configuration parameters")
  primitives <- c("numeric", "integer", "character", "logical")
  vapply(names(x), function(z) {
    zval <- x[[z]]
    if (sum(class(zval) %in% primitives)) {
      message(padspaces(z), paste(zval, collapse=" "))
    } else {
      message(padspaces(z), "[", paste(class(zval), collapse=","), "]")
    }
    z
  }, character(1))
  
  invisible(x)
}


print.MDS.config <- function(x, ...) {
  if (!is(x, "MDS.config")) {
    umap.error("x is not a MDS configuration object")
  }
  
  # produce a string of form "  z:  " of total length width
  padspaces <- function(z, width=24) {
    padleft <- max(0, width-nchar(z)-2)
    paste(c(rep(" ", padleft), z, ": "), collapse="")
  }
  
  message("MDS configuration parameters")
  primitives <- c("numeric", "integer", "character", "logical")
  vapply(names(x), function(z) {
    zval <- x[[z]]
    if (sum(class(zval) %in% primitives)) {
      message(padspaces(z), paste(zval, collapse=" "))
    } else {
      message(padspaces(z), "[", paste(class(zval), collapse=","), "]")
    }
    z
  }, character(1))
  
  invisible(x)
}


kabsch <- function(pm, qm) {
  pm_dims <- dim(pm)
  if (!all(dim(qm) == pm_dims)) {
    stop(call. = TRUE, "Point sets must have the same dimensions")
  }
  # The rotation matrix will have (ncol - 1) leading ones in the diagonal
  diag_ones <- rep(1, pm_dims[2] - 1)
  
  # center the points
  pm <- scale(pm, center = TRUE, scale = FALSE)
  qm <- scale(qm, center = TRUE, scale = FALSE)
  
  am <- crossprod(pm, qm)
  
  svd_res <- svd(am)
  # use the sign of the determinant to ensure a right-hand coordinate system
  d <- determinant(tcrossprod(svd_res$v, svd_res$u))$sign
  dm <- diag(c(diag_ones, d))
  
  # rotation matrix
  um <- svd_res$v %*% tcrossprod(dm, svd_res$u)
  
  # Rotate and then translate to the original centroid location of qm
  sweep(t(tcrossprod(um, pm)), 2, -attr(qm, "scaled:center"))
}


txtsummary = function (x, digits = 0, scientific = FALSE, range=c("IQR","95%CI")) 
{
  matchFUN=pmatch(range[1],c("IQR","95%CI"))
  if(is.na(matchFUN))
    stop("The range to be considered must be \"IQR\" or \"95%CI\".")
  
  m = median(x, na.rm = TRUE)
  
  if(matchFUN==1)
    ci = quantile(x, probs = c(0.25, 0.75), na.rm = TRUE)
  if(matchFUN==2)
    ci = quantile(x, probs = c(0.025, 0.975), na.rm = TRUE)
  if (scientific) {
    m = format(m, digits = digits, scientific = scientific)
    ci = format(ci, digits = digits, scientific = scientific)
  }
  else {
    m = round(m, digits = digits)
    ci = round(ci, digits = digits)
  }
  txt = paste(m, " [", ci[1], " ", ci[2], "]", sep = "")
  txt
}


multi_analysis =
  function (data, y, FUN = c("continuous.test", "correlation.test"), 
            ...) 
  {
    matchFUN = pmatch(FUN[1], c("continuous.test", "correlation.test"))
    if (is.na(matchFUN)) 
      stop("The function to be considered must be  \"continuous.test\" or \"correlation.test\".")
    if (matchFUN == 1) {
      FUN = continuous.test
    }
    if (matchFUN == 2) {
      FUN = correlation.test
    }
    da = NULL
    pval = NULL
    for (i in 1:ncol(data)) {
      sel.na = !is.na(data[, i])
      if (sum(sel.na) > 5) {
        temp = FUN(name = colnames(data)[i], x = data[sel.na,i], y = y[sel.na], ...)
        da = rbind(da, temp)
        pval[i] = attr(temp,"p-value")
      }
      else {
        if (matchFUN == 1) {
          da = rbind(da, c(colnames(data)[i], NA, NA,NA,NA))
        }
        if (matchFUN == 2) {
          da = rbind(da, c(colnames(data)[i], NA, NA))
        }
        
        pval[i] = NA
      }
    }
    FDR = p.adjust(pval, method = "fdr")
    FDR = format(FDR, digits = 3, scientific = TRUE)
    da = cbind(da, FDR)
    da
  }





#-----for numerical data 

continuous.test = function (name,
                            x,    
                            y,
                            digits = 3,
                            scientific = FALSE, 
                            range = c("IQR","95%CI"), 
                            logchange = FALSE,pos=2,method=c("non-parametric","parametric"),total.column=FALSE, ...) 
{
  
  
  matchFUN = pmatch(method[1], c("non-parametric", "parametric"))
  if (matchFUN != 1 & matchFUN != 2) {
    stop("Method argument should one of \"non-parametric\",\"parametric\"")
  }
  y = as.factor(y)
  ll = levels(y)
  A = x[y == ll[1]]
  B = x[y == ll[2]]
  nn = length(levels(y))
  v = data.frame(matrix(nrow = 1, ncol = nn + 3))
  v[1, 1] = name
  if (nn == 2) {
    if (matchFUN == 1) {
      pval = wilcox.test(x ~ y, exact = FALSE, ...)$p.value
    }
    if (matchFUN == 2) {
      pval = t.test(x ~ y, ...)$p.value
    }
    if (logchange == TRUE){
      fc = -log2(mean(A, na.rm = TRUE)/mean(B, na.rm = TRUE))
    }
  }
  if (nn > 2) {
    if (matchFUN == 1) {
      pval = kruskal.test(x ~ y, ...)$p.value
    }
    if (matchFUN == 2) {
      pval = summary.aov(aov(x ~ y, ...))[[1]]$`Pr(>F)`[1]
    }
    logchange = FALSE
  }
  if (nn > 1) {
    v[1, 2:(1 + nn)] = tapply(x, y, function(x) txtsummary(x, 
                                                           digits = digits, scientific = scientific, range = range))
    v[1, nn + 2] = txtsummary(x, digits = digits, scientific = scientific)
    v[1, nn + 3] = format(pval, digits = 3, scientific = TRUE)
  }
  else {
    v[1, nn + 3] = NA
  }
  matchFUN = pmatch(range[1], c("IQR", "95%CI"))
  if (pos == 1) {
    if (matchFUN == 1) {
      names(v) = c("Feature", paste(levels(y), ", median [IQR]", 
                                    sep = ""), "Total, median [IQR]", "p-value")
    }
    if (matchFUN == 2) {
      names(v) = c("Feature", paste(levels(y), ", median [95%CI]", 
                                    sep = ""), "Total, median [95%CI]", "p-value")
    }
  }
  else {
    if (matchFUN == 1) {
      v[1, 1] = paste(name, ", median [IQR]", sep = "")
    }
    if (matchFUN == 2) {
      v[1, 1] = paste(name, ", median [95%CI]", sep = "")
    }
    names(v) = c("Feature", levels(y), "Total", "p-value")
  }
  v[v == "NA [NA NA]"] = "-"
  if (logchange == TRUE) {
    v = cbind(v[1, 1:(nn + 2)], logchange = round(fc, digits = 2), 
              `p-value` = v[1, (nn + 3)])
    attr(v, "p-logchange") = fc
  }
  if (!total.column) {
    v = v[, -(nn + 2)]
  }
  attr(v, "p-value") = pval
  return(v)
}

#-----for categorical data 
categorical.test = 
  function (name, x, y,total.column=FALSE,...) 
  {
    y = as.factor(y)
    nn = length(levels(y))
    t0 = table(x, y)
    ta = cbind(t0, as.matrix(table(x)))
    tb = sprintf("%.1f", t(t(ta)/colSums(ta)) * 100)
    tc = matrix(paste(ta, " (", tb, ")", sep = ""), 
                ncol = nn + 1)
    tc[, c(colSums(t0), -1) == 0] = "-"
    v = NULL
    if (nrow(t0) == 1) {
      p.value = NA
      v[nn + 3] = ""
    }
    else {
      p.value = fisher.test(t0, workspace = 10^7,...)$p.value
      v[nn + 3] = format(p.value, digits = 3, scientific = TRUE)
    }
    v[1] = name
    group = paste("   ", rownames(ta), ", n (%)", 
                  sep = "")
    cc = cbind(group, tc, rep(NA, length(group)))
    cc = rbind(v, cc)
    #tet=table(y)
    #te=paste(c(colnames(t0),"Total")," (n=",c(tet,sum(tet)),")",sep="")
    te=c(colnames(t0),"Total")
    colnames(cc) = c("Feature", te, 
                     "p-value")
    cc[is.na(cc)] = ""
    if(!total.column){
      cc=cc[,-(nn+2)]
    }
    attr(cc,"p-value")=p.value
    return(cc)
  }





correlation.test= function(x,y,method = c("pearson", "spearman","MINE"), name=NA, perm=100 , ...){
  matchFUN = pmatch(method[1], c("pearson", "spearman","MINE"))
  if (is.na(matchFUN)) 
    stop("The method to be considered must be  \"pearson\", \"spearman\" or \"MINE\".")
  res=list()
  sel=!is.na(x) & !is.na(y)
  x=x[sel]
  y=y[sel]
  
  text = data.frame(matrix(nrow=1,ncol=3))
  text[1, 1] = name
  text[1,2]=NA
  text[1,3]=NA
  if(length(x)<5){
    warning("The number of correlated elements is less than 5.")
    estimate=NA
    p.value=NA
    
  }else{
    if(matchFUN==1){
      temp=cor.test(x,y,method="pearson")
      estimate=temp$estimate
      p.value=temp$p.value
    }
    if(matchFUN==2){
      temp=cor.test(x,y,method="spearman")
      estimate=temp$estimate
      p.value=temp$p.value
    }
    if(matchFUN==3){
      estimate=mine(x,y)$MIC
      v=NULL
      for(i in 1:perm){
        v[i]=mine(x,sample(y))$MIC
      }
      p.value=pnorm(estimate, mean = mean(v), sd = sqrt(((length(v) - 
                                                                    1)/length(v)) * var(v)), lower.tail = FALSE)
    }
    text[1,2]=round(estimate,digits=2)
    text[1,3]=format(p.value, digits = 3, scientific = TRUE)
  }
  if(matchFUN==1){
    names(text)=c("Feature","r","p-value")
  }  
  if(matchFUN==2){
    names(text)=c("Feature","rho","p-value")
  }  
  if(matchFUN==3){
    names(text)=c("Feature","MIC","p-value")
  }
  attr(text,"estimate")=estimate
  attr(text,"p-value")=p.value
  return(text)
}



pca = function(x,...){
  res=prcomp(x,...)
  ss=sprintf("%.1f",summary(res)$importance[2,]*100)
  res$txt = paste(names(summary(res)$importance[2,])," (",ss,"%)",sep="")
  colnames(res$x)=res$txt
  res
}


KODAMA.matrix =
function (data, M = 100, Tcycle = 20, FUN_VAR = function(x) {
  ceiling(ncol(x))
}, FUN_SAM = function(x) {
  ceiling(nrow(x) * 0.75)
}, bagging = FALSE, FUN = c("PLS-DA", "KNN"), f.par = 5, W = NULL, 
constrain = NULL, fix = NULL, epsilon = 0.05, dims = 2, landmarks = 10000, 
neighbors = min(c(landmarks, nrow(data)/3)) + 1, spatial = NULL, 
spatial.knn = 10,splitting=50) 
{
  if(is.null(spatial)){
    spatial=data
    spatial_flag=TRUE
  }  
  else{
    spatial_flag=FALSE
  }
  if (sum(is.na(data)) > 0) {
    stop("Missing values are present")
  }
  if (is.null(fix)) 
    fix = rep(FALSE, nrow(data))
  if (is.null(constrain)) 
    constrain = 1:nrow(data)
  data = as.matrix(data)
  shake = FALSE
  nsample = nrow(data)
  landpoints = NULL
  nlandmarks = landmarks
  if (length(landmarks) > 1) {
    if (max(landmarks) > nsample) {
      stop("A selected landmark exceed the number of entries")
    }
    if (length(table(table(landmarks))) > 1) {
      stop("Repeated landmarks are not allowed")
    }
    if (length(landmarks) > nsample) {
      stop("The number of landmarks exceed the number of entries")
    }
    nlandmarks = length(landmarks)
  }
  
  # If LMARK is TRUE, the landmark approach will be performed
  LMARK = (nsample > nlandmarks)
  if (LMARK) {
    if (length(landmarks) > 1) {
      landpoints = landmarks
    }
    else {
      landpoints = sort(sample(nrow(data), landmarks))
      clust = as.numeric(kmeans(data, landmarks)$cluster)
      landpoints = NULL
      for (ii in 1:landmarks) {
        www = which(clust == ii)
        if (length(www) == 1) {
          landpoints = c(landpoints, www)
        }
        else {
          landpoints = c(landpoints, sample(www)[1])
        }
      }
    }
    Tdata = data[-landpoints, , drop = FALSE]
    Xdata = data[landpoints, , drop = FALSE]
    Xdata_landpoints = Xdata
    Tfix = fix[-landpoints]
    Xfix = fix[landpoints]
    Tconstrain = constrain[-landpoints]
    Xconstrain = constrain[landpoints]
    vect_proj = matrix(NA, nrow = M, ncol = nrow(Tdata))
    
    Xspatial = spatial[landpoints, ,drop=FALSE]
    Tspatial = spatial[-landpoints, ,drop=FALSE]
    
  }
  else {
    Xdata = data
    Xdata_landpoints = Xdata
    Xfix = fix
    Xconstrain = constrain
    landpoints = 1:nsample
    
    Xspatial = spatial
    Tspatial = NULL

  }
  nva = ncol(Xdata)
  nsa = nrow(Xdata)
  res = matrix(nrow = M, ncol = nsa)
  ma = matrix(0, ncol = nsa, nrow = nsa)
  normalization = matrix(0, ncol = nsa, nrow = nsa)
  FUN_VAR = FUN_VAR(Xdata)
  FUN_SAM = FUN_SAM(Xdata)
  if (f.par > FUN_VAR & FUN[1] == "PLS-DA") {
    message("The number of components selected for PLS-DA is too high and it will be automatically reduced to ", 
            FUN_VAR)
    f.par = FUN_VAR
  }
    if (f.par > FUN_VAR & FUN[1] == "KNNPLS-DA") {
    message("The number of components selected for PLS-DA is too high and it will be automatically reduced to ", 
            FUN_VAR)
    f.par = FUN_VAR
  }
  vect_acc = matrix(NA, nrow = M, ncol = Tcycle)
  accu = NULL
  whF = which(!Xfix)
  whT = which(Xfix)
  FUN_SAM = FUN_SAM - length(whT)
  pb <- txtProgressBar(min = 1, max = M, style = 1)
  for (k in 1:M) {
    setTxtProgressBar(pb, k)
  #  if (LMARK) {
  #    ks = round(nsample/nlandmarks)
  #    tt = knn_Armadillo(data, data[landpoints, ], k = ks)$nn_index
  #    landpoints2 = landpoints
  #    for (ii in 1:landmarks) {
  #      landpoints2[ii] = tt[ii, sample(ks, 1)]
  #    }
  #    Xdata = data[landpoints2, , drop = FALSE]
  #    if (is.matrix(spatial)) {
  #      spatial = spatial[landpoints2, ]
  #    }
  #  }
    
    
    
    
    sva = sample(nva, FUN_VAR, FALSE, NULL)
    ssa = c(whT, sample(whF, FUN_SAM, bagging, NULL))
    
 ##################################################################################333   Xspatial_ssa = Xspatial[ssa, ]
    if (LMARK) {
      xTdata = Tdata[, sva]

      if(spatial_flag){
        Tspatial_ssa = Tspatial[,sva]
        Xspatial_ssa = Xspatial[ssa,sva]
      }
      else{
        Tspatial_ssa = Tspatial
        Xspatial_ssa = Xspatial[ssa,]
      }
    }
    else {
      xTdata = NULL
      Xspatial_ssa = Xspatial[ssa,]
      Tspatial_ssa=NULL
      if(spatial_flag){
        Xspatial_ssa = Xspatial[,sva]
      }
    }

    
    x = Xdata[ssa, sva]
    xva = ncol(x)
    xsa = nrow(x)
    Xconstrain_ssa = as.numeric(as.factor(Xconstrain[ssa]))
    Xconstrain_ssa_previous = Xconstrain[ssa]
    Xfix_ssa = Xfix[ssa]
    del_n = rep(NA, nrow(x))
    for (ik in 1:(nrow(x) - 1)) {
      if (is.na(del_n[ik])) {
        del_n[ik] = ik
        for (ij in 2:nrow(x)) {
          if (all(x[ik, ] == x[ij, ])) 
            del_n[ij] = ik
        }
      }
    }
    if (is.na(del_n[nrow(x)])) 
      del_n[nrow(x)] = nrow(x)
    xsa_same_point = length(unique(del_n))
    if (is.null(W)) {
      if (xsa_same_point <= 200 || length(unique(x)) < 
          50) {
        XW = Xconstrain_ssa
      }
      else {
        #Test spatial modify x with Xspatial_ssa
        clust = as.numeric(kmeans(Xspatial_ssa, splitting)$cluster)
        tab = apply(table(clust, Xconstrain_ssa), 2, 
                    which.max)
        XW = as.numeric(as.factor(tab[as.character(Xconstrain_ssa)]))
      }
    }
    else {
      XW = W[landpoints][ssa]
      if (any(is.na(XW))) {
        if (xsa_same_point <= 200 || length(unique(x)) < 
            50) {
          unw = unique(XW)
          unw = unw[-which(is.na(unw))]
          ghg = is.na(XW)
          nnew = length(unique(Xconstrain_ssa[ghg]))
          XW[ghg] = as.numeric(as.factor(Xconstrain_ssa[ghg])) + 
            length(unw)
        }
        else {
          
          #Test spatial modify x with Xspatial_ssa
          clust = as.numeric(kmeans(Xspatial_ssa, splitting)$cluster)
          tab = apply(table(clust, Xconstrain_ssa), 2, 
                      which.max)
          constrain_temp = as.numeric(as.factor(tab[as.character(Xconstrain_ssa)]))
          unw = unique(XW)
          unw = unw[-which(is.na(unw))]
          ghg = is.na(XW)
          nnew = length(unique(constrain_temp[ghg]))
          XW[ghg] = as.numeric(as.factor(constrain_temp[ghg])) + 
            length(unw)
        }
      }
    }
    clbest = XW
#    if (LMARK) {
#      xTdata = Tdata[, sva]
#      Tspatial = Tspatial[,sva]
#      Xspatial = Xspatial[,sva]
#      
#    }
#    else {
#      xTdata = NULL
#      Xspatial = Xspatial[,sva]
#    }


 #     xNeighbors = knn_Armadillo(as.matrix(Xspatial_ssa), as.matrix(x), 
 #                                spatial.knn)$nn_index

    options(warn=-1)
    yatta=0
    attr(yatta,"class")="try-error"
    while(!is.null(attr(yatta,"class"))){
      
    yatta = try(core_cpp(x, xTdata, clbest, Tcycle, FUN, f.par, 
                     Xconstrain_ssa, Xfix_ssa, shake, Xspatial_ssa,Tspatial_ssa,spatial.knn),silent = FALSE)
      if(!is.null(attr(yatta,"class"))){
        save(x, xTdata, clbest, Tcycle, FUN, f.par, 
                     Xconstrain_ssa, Xfix_ssa, shake, Xspatial_ssa,Tspatial_ssa,spatial.knn,file="Chepalle.RData")
      }
    }
    options(warn=0)
    if (is.list(yatta)) {
      clbest = as.vector(yatta$clbest)
      accu = yatta$accbest
      yatta$vect_acc = as.vector(yatta$vect_acc)
      yatta$vect_acc[yatta$vect_acc == -1] = NA
      vect_acc[k, ] = yatta$vect_acc
      if (LMARK) {
        yatta$vect_proj = as.vector(yatta$vect_proj)
        yatta$vect_proj[Tfix] = W[-landpoints][Tfix]
        vect_proj[k, ] = yatta$vect_proj
      }
      uni = unique(clbest)
      nun = length(uni)
      for (ii in 1:nun) ma[ssa[clbest == uni[ii]], ssa[clbest == 
                                                         uni[ii]]] = ma[ssa[clbest == uni[ii]], ssa[clbest == 
                                                                                                      uni[ii]]] + 1
      normalization[ssa, ssa] = normalization[ssa, ssa] + 
        1
      res[k, ssa] = clbest
    }
  }
  close(pb)
  ma = ma/normalization
  Edist = as.matrix(dist(Xdata_landpoints))
  ma[ma < epsilon] = 0
  mam = (1/ma) * Edist
  mam[is.na(mam)] <- .Machine$double.xmax
  mam[is.infinite(mam) & mam > 0] <- .Machine$double.xmax
  mam = floyd(mam)
  mam[mam == .Machine$double.xmax] <- NA
  prox = Edist/mam
  diag(prox) = 1
  prox[is.na(prox)] = 0
  maxvalue = max(mam, na.rm = TRUE)
  mam[is.na(mam)] = maxvalue
  y = ma
  diag(y) = NA
  yy = as.numeric(y)
  yy = yy[!is.na(yy)]
  yy = yy/sum(yy)
  H = -sum(ifelse(yy > 0, yy * log(yy), 0))
  dissimilarity = mam
  if (LMARK) {
    total_res = matrix(nrow = M, ncol = nsample)
    total_res[, landpoints] = res
    total_res[, -landpoints] = vect_proj
    knn_Armadillo = knn_Armadillo(data, data, neighbors + 
                                    1)
    knn_Armadillo$distances = knn_Armadillo$distances[, -1]
    knn_Armadillo$nn_index = knn_Armadillo$nn_index[, -1]
    for (i_tsne in 1:nrow(data)) {
      for (j_tsne in 1:neighbors) {
        kod_tsne = mean(total_res[, i_tsne] == total_res[, 
                                                         knn_Armadillo$nn_index[i_tsne, j_tsne]], na.rm = TRUE)
        knn_Armadillo$distances[i_tsne, j_tsne] = knn_Armadillo$distances[i_tsne, 
                                                                          j_tsne]/kod_tsne
      }
      oo_tsne = order(knn_Armadillo$distance[i_tsne, ])
      knn_Armadillo$distances[i_tsne, ] = knn_Armadillo$distances[i_tsne, 
                                                                  oo_tsne]
      knn_Armadillo$nn_index[i_tsne, ] = knn_Armadillo$nn_index[i_tsne, 
                                                                oo_tsne]
    }
  }
  else {
    knn_Armadillo = list()
    knn_Armadillo$nn_index = matrix(ncol = ncol(mam), nrow = nrow(mam))
    for (i_tsne in 1:nrow(data)) {
      oo_tsne = order(mam[i_tsne, ])
      mam[i_tsne, ] = mam[i_tsne, oo_tsne]
      knn_Armadillo$nn_index[i_tsne, ] = oo_tsne
    }
    knn_Armadillo$nn_index = knn_Armadillo$nn_index[, -1][, 
                                                          1:neighbors]
    knn_Armadillo$distances = mam[, -1][, 1:neighbors]
    total_res = res
  }
  knn_Armadillo$neighbors = neighbors
  return(list(dissimilarity = dissimilarity, acc = accu, proximity = ma, 
              v = vect_acc, res = total_res, f.par = f.par, entropy = H, 
              landpoints = landpoints, knn_Armadillo = knn_Armadillo, 
              data = data))
}

KODAMA.visualization=function(kk,method=c("t-SNE","MDS","UMAP"),config=NULL){
  
  mat=c("t-SNE","MDS","UMAP")[pmatch(method,c("t-SNE","MDS","UMAP"))[1]]

  if(mat=="t-SNE"){ 
    if(is.null(config)){
      config = Rtsne.defaults
    }
    if(config$perplexity>(floor(nrow(kk$data)/3)-1)){
      stop("Perplexity is too large for the number of samples")
    }
  #  if(config$perplexity>(floor((kk$knn_Armadillo$neighbors+1)/3)-1)){
  #    stop("Perplexity is too large for the distance matrix created. Please, increase the number of neighbors")
  #  }
    
    ntsne=min(round(config$perplexity)*3,nrow(kk$data)-1)

    if(is.null(config$stop_lying_iter)){
      config$stop_lying_iter = ifelse(is.null(config$Y_init), 250L, 0L)
    }

    if(is.null(config$mom_switch_iter)){
      config$mom_switch_iter = ifelse(is.null(config$Y_init), 250L, 0L)
    }
    res_tsne=Rtsne_neighbors(kk$knn_Armadillo$nn_index,kk$knn_Armadillo$distances,
                             dims = config$dims,
                             perplexity = config$perplexity,
                             theta = config$theta,
                             max_iter = config$max_iter,
                             verbose = config$verbose,
                             Y_init = config$Y_init,
                             stop_lying_iter = config$stop_lying_iter,
                             mom_switch_iter = config$mom_switch_iter,
                             momentum = config$momentum,
                             final_momentum = config$final_momentum,
                             eta = config$eta,
                             exaggeration_factor = config$exaggeration_factor,
                             num_threads = config$num_threads)
  dimensions=res_tsne$Y
  #res_tsne=within(res_tsne, rm(Y))
  res_tsne=res_tsne[names(res_tsne)!="Y"]
    colnames(dimensions)[1:config$dims] = paste ("Dimension", 1:config$dims)
    rownames(dimensions)=rownames(kk$data)
    
  }
  if(mat=="MDS"){ 
    if(is.null(config)){
      config = MDS.defaults
    }
    dimensions=cmdscale(kk$dissimilarity)
    colnames(dimensions)[1:config$dims] = paste ("Dimension", 1:config$dims)
    rownames(dimensions)=rownames(kk$data)
  }
  if(mat=="UMAP"){ 
    if(is.null(config)){
      config = umap.defaults
    }
    u=umap.knn(kk$knn_Armadillo$nn_index,kk$knn_Armadillo$distances)
    config$knn=u

    dimensions = umap(kk$data,knn=u,config=config)$layout
    colnames(dimensions)[1:config$n_components] = paste ("Dimension", 1:config$n_components)
    rownames(dimensions)=rownames(kk$data)
  }
  dimensions 
}





  
# This function performs a permutation test to assess association between the 
# KODAMA output and any additional related parameters such as clinical metadata.

#k.test = function (data, labels, n = 100) 
#{
#  data=as.matrix(data)
#  compmax=min(dim(data))
#  option=2-as.numeric(is.factor(label))
#  w_R2Y=NULL
#  for(i in 1:n){
#    w_R2Y[i]=double_pls_cv(data,as.matrix(as.numeric(labels)),1:nrow(data),option,2,compmax,1,1)$R2Y
#  }
#  v_R2Y=NULL
#  for(i in 1:n){
#    ss=sample(1:nrow(data))
#    v_R2Y[i]=double_pls_cv(data,as.matrix(as.numeric(labels[ss])),1:nrow(data),option,2,compmax,1,1)$R2Y
#  }
#  pval=wilcox.test(w_R2Y,v_R2Y,alternative = "greater")$p.value
#  pval
#}
k.test = 
  function (data, labels, n = 100) 
  {
    data = as.matrix(data)
    compmax = min(dim(data))
    option = 2 - as.numeric(is.factor(labels))
    
    w_R2Y = pls.double.cv(data, labels, 1:nrow(data),compmax = 2,perm.test = FALSE,times = 1,runn=1)$medianR2Y
    
    v_R2Y = NULL
    for (i in 1:n) {
      ss = sample(1:nrow(data))
      v_R2Y[i] = pls.double.cv(data, labels[ss], 1:nrow(data),compmax = 2,perm.test = FALSE,times = 1,runn=1)$medianR2Y
    }
    pval = sum(v_R2Y>w_R2Y)/n
    pval
  }




# This function can be used to extract the variable ranking.

loads = function (model,method=c("loadings","kruskal.test")) 
{
  mat=pmatch(method,c("loadings","kruskal.test"))[1]
  nn = nrow(model$res)
  for (i in 1:nn) {
    clu = model$res[i, ]
    na.clu = !is.na(clu)
    clu = clu[na.clu]
    clu=as.numeric(as.factor(clu))
    red.out = matrix(ncol = ncol(model$data), nrow = nn)
    if (length(unique(clu)) > 1) {
      if(mat==1)
         red.out[i, ] = as.numeric(pls.kodama(Xtrain = model$data[na.clu,], 
                                              Xtest  = model$data[na.clu,], 
                                              as.factor(clu), ncomp = 1)$P[, 1])
      if(mat==2)
         red.out[i, ] = apply(model$data,2,function(x) -log(kruskal.test(x[na.clu],as.factor(clu))$p.value))
    }
  }
  colMeans(abs(red.out), na.rm = TRUE)
}




mcplot = function (model){
  A=model$v
  A[,1]=0
  plot(A[1,],type="l",xlim=c(1,ncol(model$v)),ylim=c(0,1),xlab="Numer of interatation",ylab="Accuracy")
  for(i in 1:nrow(A))
      points(A[i,],type="l")
}




core_cpp <- function(x, 
                     xTdata=NULL,
                     clbest, 
                     Tcycle=20, 
                     FUN=c("PLS-DA","KNN"), 
                     fpar=2, 
                     constrain=NULL, 
                     fix=NULL, 
                     shake=FALSE,
                     posxy=NULL,
                     posxyTdata=NULL,
                     neighbors=10) {
  
  if (is.null(constrain)) 
    constrain = 1:length(clbest)
  
  if (is.null(fix)) 
    fix = rep(FALSE, length(clbest))
  if(is.null(xTdata)){
    xTdata=matrix(1,ncol=1,nrow=1)
    proj=1
  }else{
    proj=2
  }
  if(is.null(posxyTdata)){
    posxyTdata=matrix(1,ncol=1,nrow=1)
  }
  matchFUN=pmatch(FUN[1],c("KNN","PLS-DA","KNNPLS-DA"))
  if(is.na(matchFUN))
    stop("The classifier to be considered must be  \"PLS-DA\" or \"KNN\".")
  
  out=corecpp(x, xTdata,clbest, Tcycle, matchFUN, fpar, constrain, fix, shake,proj,posxy, posxyTdata,neighbors)
  return(out)
}






pls.double.cv = function(Xdata,
                         Ydata,
                         constrain=1:nrow(Xdata),
                         compmax=min(5,c(ncol(Xdata),nrow(Xdata))),
                         perm.test=FALSE,
                         optim=TRUE,
                         scaling=c("centering","autoscaling"),
                         times=100,
                         runn=10){

  if(sum(is.na(Xdata))>0) {
    stop("Missing values are present")
  } 
  scal=pmatch(scaling,c("centering","autoscaling"))[1]
  optim=as.numeric(optim)
  Xdata=as.matrix(Xdata)
  constrain=as.numeric(as.factor(constrain))
  res=list()
  Q2Y=NULL
  R2Y=NULL
  bcomp=NULL
  if(is.factor(Ydata)){
    lev=levels(Ydata)
    

    for(j in 1:runn){

      o=double_pls_cv(Xdata,as.matrix(as.numeric(Ydata)),constrain,1,2,compmax,optim,scal)
      bcomp[j]=o$bcomp
      o$Ypred=factor(lev[o$Ypred],levels=lev)
      o$conf=table(o$Ypred,Ydata)
      o$acc=(sum(diag(o$conf))*100)/length(Ydata)
      o$Yfit=factor(lev[o$Yfit],levels=lev)
      o$R2X=diag((t(o$T)%*%(o$T))%*%(t(o$P)%*%(o$P)))/sum(scale(Xdata,TRUE,TRUE)^2)
      Q2Y[j]=o$Q2Y
      R2Y[j]=o$R2Y
      res$results[[j]]=o
      
    }
    res$Q2Y=Q2Y
    res$R2Y=R2Y
    res$medianR2Y=median(R2Y)
    res$CI95R2Y=as.numeric(quantile(R2Y,c(0.025,0.975)))
    res$medianQ2Y=median(Q2Y)
    res$CI95Q2Y=as.numeric(quantile(Q2Y,c(0.025,0.975)))
    res$bcomp=floor(median(bcomp,na.rm = TRUE))
    
    bb=NULL;for(h in 1:runn) bb[h]=res$results[[h]]$bcomp
    run = which(bb==res$bcomp)[1]
    
    res$T=res$results[[run]]$T
    res$Q=res$results[[run]]$Q
    res$P=res$results[[run]]$P
    res$B=res$results[[run]]$B
    
    mpred=matrix(ncol=runn,nrow=nrow(Xdata));
    for(h in 1:runn) mpred[,h]= as.vector(res$results[[h]]$Ypred)
    res$Ypred=apply(mpred,1,function(x) names(which.max(table(x))))
    
    for(h in 1:runn) mpred[,h]= as.vector(res$results[[h]]$Yfit)
    res$Yfit=apply(mpred,1,function(x) names(which.max(table(x))))
    
    if(perm.test){

      v=NULL
   
      for(i in 1:times){
        ss=sample(1:nrow(Xdata))
        w=NULL
        for(ii in 1:runn)
          w[ii]=double_pls_cv(Xdata[ss,],as.matrix(as.numeric(Ydata)),constrain,1,2,compmax,optim,scal)$Q2Y
        
        v[i]=median(w)
      }
      pval=pnorm(median(Q2Y), mean=mean(v), sd=sqrt(((length(v)-1)/length(v))*var(v)), lower.tail=FALSE) 
      res$Q2Ysampled=v
  #    res$p.value=wilcox.test(Q2Y,v,alternative = "greater")$p.value     
      res$p.value=pval
      
    }
  
  }else{

    for(j in 1:runn){

      o=double_pls_cv(Xdata,as.matrix(Ydata),constrain,2,2,compmax,optim,scal)
      bcomp[j]=o$bcomp
      o$Yfit=as.numeric(o$Yfit)
      o$Ypred=as.numeric(o$Ypred)
      o$R2X=diag((t(o$T)%*%(o$T))%*%(t(o$P)%*%(o$P)))/sum(scale(Xdata,TRUE,TRUE)^2)
      Q2Y[j]=o$Q2Y
      R2Y[j]=o$R2Y
      res$results[[j]]=o
    }
    res$Q2Y=Q2Y
    res$Q2Y=Q2Y
    res$R2Y=R2Y
    res$medianR2Y=median(R2Y)
    res$CI95R2Y=as.numeric(quantile(R2Y,c(0.025,0.975)))
    res$medianQ2Y=median(Q2Y)
    res$CI95Q2Y=as.numeric(quantile(Q2Y,c(0.025,0.975)))
    res$bcomp=floor(median(bcomp,na.rm = TRUE))
    
    
    bb=NULL;for(h in 1:runn) bb[h]=res$results[[h]]$bcomp
    run = which(bb==res$bcomp)[1]
    
    res$T=res$results[[run]]$T
    res$Q=res$results[[run]]$Q
    res$P=res$results[[run]]$P
    res$B=res$results[[run]]$B
    
    mpred=matrix(ncol=runn,nrow=nrow(Xdata));
    for(h in 1:runn) mpred[,h]= as.vector(res$results[[h]]$Ypred)
    res$Ypred=apply(mpred,1,function(x) median(x))
    
    for(h in 1:runn) mpred[,h]= as.vector(res$results[[h]]$Yfit)
    res$Yfit=apply(mpred,1,function(x) median(x))
    
    pval=NULL
    if(perm.test){

      v=NULL
      
      for(i in 1:times){
        ss=sample(1:nrow(Xdata))
        w=NULL
        for(ii in 1:runn)

          w[ii]=double_pls_cv(Xdata[ss,],as.matrix(Ydata),constrain,2,2,compmax,optim,scal)$Q2Y

        v[i]=median(w)
      }
      pval=pnorm(median(Q2Y), mean=mean(v), sd=sqrt(((length(v)-1)/length(v))*var(v)), lower.tail=FALSE) 
      res$Q2Ysampled=v
      #    res$p.value=wilcox.test(Q2Y,v,alternative = "greater")$p.value     
      res$p.value=pval
    }

  }
  res$txtQ2Y=txtsummary(res$Q2Y,digits=2)
  res$txtR2Y=txtsummary(res$R2Y,digits=2)
  res
}





knn.double.cv = function(Xdata,
                         Ydata,
                         constrain=1:nrow(Xdata),
                         compmax=min(5,c(ncol(Xdata),nrow(Xdata))),
                         perm.test=FALSE,
                         optim=TRUE,
                         scaling=c("centering","autoscaling"),
                         times=100,
                         runn=10){

  scal=pmatch(scaling,c("centering","autoscaling"))[1]
  optim=as.numeric(optim)
  Xdata=as.matrix(Xdata)
  constrain=as.numeric(as.factor(constrain))
  
  res=list()
  Q2Y=NULL
  R2Y=NULL
  bk=NULL
  
  if(is.factor(Ydata)){
    lev=levels(Ydata)

    for(j in 1:runn){

      o=double_knn_cv(Xdata,as.numeric(Ydata),constrain,1,2,compmax,optim,scal)
      o$conf=table(o$Ypred,Ydata)
      o$acc=(sum(diag(o$conf))*100)/length(Ydata)
      o$Yfit=factor(lev[o$Yfit],levels=lev)
      o$Ypred=factor(lev[o$Ypred],levels=lev)
      Q2Y[j]=o$Q2Y
      R2Y[j]=o$R2Y
      bk[j]=o$bk
      res$results[[j]]=o
      
      

    }
    
    res$Q2Y=Q2Y
    res$R2Y=R2Y
    res$medianR2Y=median(R2Y)
    res$CI95R2Y=as.numeric(quantile(R2Y,c(0.025,0.975)))
    res$medianQ2Y=median(Q2Y)
    res$CI95Q2Y=as.numeric(quantile(Q2Y,c(0.025,0.975)))
    res$bk=floor(median(bk,na.rm = TRUE))
    
    mpred=matrix(ncol=runn,nrow=nrow(Xdata));
    for(h in 1:runn) mpred[,h]= as.vector(res$results[[h]]$Ypred)
    res$Ypred=apply(mpred,1,function(x) names(which.max(table(x))))
    
    for(h in 1:runn) mpred[,h]= as.vector(res$results[[h]]$Yfit)
    res$Yfit=apply(mpred,1,function(x) names(which.max(table(x))))
    
    
    pval=NULL
    if(perm.test){
      
      v=NULL
      
      for(i in 1:times){
        ss=sample(1:nrow(Xdata))
        w=NULL
        for(ii in 1:runn)
          
          w[ii]=double_knn_cv(Xdata[ss,],as.numeric(Ydata),constrain,1,2,compmax,optim,scal)$Q2Y
        
        v[i]=median(w)
      }

      
      pval=pnorm(median(Q2Y), mean=mean(v), sd=sqrt(((length(v)-1)/length(v))*var(v)), lower.tail=FALSE) 
      res$Q2Ysampled=v
      #    res$p.value=wilcox.test(Q2Y,v,alternative = "greater")$p.value     
      res$p.value=pval
    }
    

    
    
  
  }else{

    for(j in 1:runn){
 
      o=double_knn_cv(Xdata,as.numeric(Ydata),constrain,2,2,compmax,optim,scal)
      o$Yfit=as.numeric(o$Yfit)
      o$Ypred=as.numeric(o$Ypred)
      Q2Y[j]=o$Q2Y
      R2Y[j]=o$R2Y
      bk[j]=o$bk
      res$results[[j]]=o
    }
    res$Q2Y=Q2Y
    res$R2Y=R2Y
    res$medianR2Y=median(R2Y)
    res$CI95R2Y=as.numeric(quantile(R2Y,c(0.025,0.975)))
    res$medianQ2Y=median(Q2Y)
    res$CI95Q2Y=as.numeric(quantile(Q2Y,c(0.025,0.975)))
    res$bk=floor(median(bk,na.rm = TRUE))
    
    mpred=matrix(ncol=runn,nrow=nrow(Xdata));
    for(h in 1:runn) mpred[,h]= as.vector(res$results[[h]]$Ypred)
    res$Ypred=apply(mpred,1,function(x) median(x))
    
    for(h in 1:runn) mpred[,h]= as.vector(res$results[[h]]$Yfit)
    res$Yfit=apply(mpred,1,function(x) median(x))
    
    pval=NULL
    if(perm.test){

      
      v=NULL
      
      for(i in 1:times){
        ss=sample(1:nrow(Xdata))
        w=NULL
        for(ii in 1:runn)
          
          w[ii]=double_knn_cv(Xdata[ss,],as.numeric(Ydata),constrain,2,2,compmax,optim,scal)$Q2Y
        
        v[i]=median(w)
      }

      pval=pnorm(median(Q2Y), mean=mean(v), sd=sqrt(((length(v)-1)/length(v))*var(v)), lower.tail=FALSE) 
      res$Q2Ysampled=v
      #    res$p.value=wilcox.test(Q2Y,v,alternative = "greater")$p.value     
      res$p.value=pval
    }
    

  }
  res$txtQ2Y=txtsummary(res$Q2Y,digits=2)
  res$txtR2Y=txtsummary(res$R2Y,digits=2)
  res
}






















frequency_matching = function(data,label,times=5,seed=1234){

  data=as.data.frame(data)
  data2=data
  for(i in 1:ncol(data2)){
    if(is.numeric(data2[,i])){
    
    v <- quantile(data2[,i],prob=seq(0,0.99,0.2))
    data2[,i]= findInterval(data2[,i], v)
    }
  }
  if(is.null(rownames(data2))){
    rownames(data2)=paste("S",1:nrow(data2),sep="")
    rownames(data)=paste("S",1:nrow(data),sep="")
  }
  names(label)=rownames(data2)
  data2=as.matrix(data2[!is.na(label),])
  label=label[!is.na(label)]
  
  minor=names(which.min(table(label)))
  major=names(which.max(table(label)))
  data_minor=data2[label==minor,,drop=FALSE]
  data_major=data2[label==major,,drop=FALSE]
  
  nc=ncol(data2)
  grid=list()
  count=list()
  rest=list()
  for(j in 1:nc){
    
    lis=list()
    
    h=1
    for(i in j:nc){
      lis[[h]]=levels(as.factor(data2[,i]))
      h=h+1
    }
    grid[[j]]=as.matrix(expand.grid(lis))
    
    co = apply(grid[[j]],1,function(y) sum(apply(as.matrix(data_minor)[,j:nc,drop=FALSE],1,function(x) all(y==x))))
    count[[j]]=co*times
  }
  rest=list()
  rest[[1]]=count[[1]]
  selected=rep(FALSE,nrow(data_major))
  names(selected)=rownames(data_major)
  for(j in 1:nc){
    if(sum(rest[[j]])>0){
      for(i in 1:nrow(grid[[j]])){
        if(rest[[j]][i]!=0){
          who=apply(as.matrix(data_major[,j:nc]),1,function(x) all(grid[[j]][i,]==x))
          n_who=min(sum(who[!selected]),rest[[j]][i])
          rest[[j]][i]=rest[[j]][i]-n_who
          set.seed(seed)
          ss=sample(names(which(who[!selected])),n_who)
          selected[ss]=TRUE
        }
      }
      if(j<nc){
        temp=list()
        for(ii in 2:ncol(grid[[j]]))   temp[[ii-1]]=as.matrix(grid[[j]])[,ii]
        rest[[j+1]]=aggregate(rest[[j]], by=temp, FUN=sum, na.rm=TRUE)[,"x"]
      }else{
        rest[[j+1]]=sum(rest[[j]])
      }
      
    }
  }
  if(sum(rest[[j]])>0){
    set.seed(seed)
    ss=sample(which(!selected),rest[[j+1]])   ###BUGGGG
    selected[ss]=TRUE
  }
  
  selection=c(rownames(data_major[selected,,drop=FALSE]),rownames(data_minor))
  
  
  data=data[selection,]
  data2=data2[selection,]
  label=label[selection]
  return(list(data=data,label=label,selection=selection))#,grid=grid,rest=rest))
}



