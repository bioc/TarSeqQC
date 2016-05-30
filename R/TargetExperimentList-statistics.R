#'@include TargetExperimentList-print.R
#'@name summary
#'@rdname TargetExperiment-statistics
#'@inheritParams summary
#'@exportMethod summary
#'@docType methods
#'@aliases summary,TargetExperimentList-method
#'@note see full example in \code{\link{TargetExperimentList-class}}
#'@author Gabriela A. Merino \email{gmerino@@bdmg.com.ar}, Cristobal Fresno
#'\email{cfresno@@bdmg.com.ar} and Elmer A. Fernandez 
#'\email{efernandez@@bdmg.com.ar}
#'@examples
#'## Loading the TargetExperimentList object
#'data(TEList, package="TarSeqQC")
#'# Object summary
#'summary(TEList)
setMethod(f="summary", signature=signature(object="TargetExperimentList"),
definition=function(object,...){

    df_panel<-as.data.frame(getPanels(object))
    index<-do.call(c, lapply(1:ncol(df_panel), function(i){
        if(strsplit(colnames(df_panel)[i], split="_")[[1]][[1]] == 
            getAttribute(object)){
            return(i)}
    }))
    listNames<-do.call(c,lapply(colnames(df_panel[,index]), function(j){
        return(strsplit(j, split=paste(getAttribute(object), "_", sep="")
            )[[1]][2])
    }))
    dfF<-lapply(1:length(index), function(i){ #hacer este una lista
    
        attrSumm<-round(summary(df_panel[,index[i]]))
        if( "pool" %in% names(df_panel)){
            pool_summary<-(ddply(df_panel, "pool", function(x){
                round(summary(x[,index[i]]))
            }))
            pool_names<-paste("pool", pool_summary[,1], sep=" ")
            df<-data.frame(cbind(attrSumm),t(pool_summary[,-1]))
            names(df)<-c(getFeature(object), pool_names)
        }else{
            df<-data.frame(as.matrix(attrSumm))
            names(df)<-c(getFeature(object))
        }
        dfF<-t(df)
        colnames(dfF)<-rownames(df)
        return(dfF)
    })
    names(dfF)<-listNames
    return(dfF)
})
#'@exportMethod summaryIntervals
#'@name summaryIntervals
#'@inheritParams summaryFeatureLev
#'@rdname TargetExperiment-statistics
#'@aliases summaryIntervals,TargetExperimentList-method
#'@examples
#'# Defining the attribute interval extreme values
#'attributeThres<-c(0,1,50,200,500, Inf)
#'# Doing a frequency table for the attribute intervals
#'summaryIntervals(TEList, attributeThres=attributeThres)
setMethod(f="summaryIntervals",signature=signature(object=
"TargetExperimentList"), definition=function(object,attributeThres= c(0, 1, 50,
200, 500, Inf), pool=FALSE){

    if(pool & !("pool" %in% names(mcols(getBedFile(object))))){
        stop("'pool' was set as TRUE but the bed file doesn't contain a 'pool'
            column")
    }
    df_panel<-as.data.frame(getPanels(object))
    index<-do.call(c, lapply(1:ncol(df_panel), function(i){
        if(strsplit(colnames(df_panel)[i], split="_")[[1]][[1]] == 
            getAttribute(object)){
            return(i)}
    }))
    listNames<-do.call(c,lapply(colnames(df_panel[,index]), function(j){
        return(strsplit(j, split=paste(getAttribute(object), "_", sep="")
            )[[1]][2])
    }))
    if(pool){
    index_p<-which(colnames(df_panel) == "pool")
    }else index_p<-NULL

    if(attributeThres[length(attributeThres)] < Inf){
        attributeThres<-c(attributeThres, Inf)
    }
    interval_names<-sapply(1:length(attributeThres[attributeThres != "Inf"]),
    function(x){
        if(x < length(attributeThres[attributeThres != "Inf"])) {
            return((paste(attributeThres[x], " <= ", getAttribute(object)," < ",
            attributeThres[x+1])))
        }else{
            paste(  getAttribute(object), " >= ", attributeThres[x])
        }
    })
    interval_names<-cbind(interval_names, nmb=1:length(interval_names))
    # creating a new variable 'score' that groups the features according to 
    # their attribute value and defined intervals
    scores<-as.data.frame(do.call(cbind,lapply(1:length(index), function(i){
        return(cut(df_panel[,index[i]], 
            breaks=attributeThres, include.lowest=TRUE, right=FALSE,
            dig.lab = 6))
    
    })))
    scores<-as.data.frame(do.call(cbind, lapply(1:ncol(scores), function(i){
        return(interval_names[match(scores[,i], interval_names[,"nmb"]),
            "interval_names"])
    
    })))
    colnames(scores)<-paste(listNames,"scores", sep="_")

    df_panel<-cbind(df_panel, scores) 
    
    if(pool){
        aux<-NULL
        for (i in 1: ncol(scores)){
            aux<-c(aux, as.character(scores[,i]))
        }
        aux<-data.frame(score=factor(aux, levels=interval_names[,
            "interval_names"]), pool=rep(df_panel[,"pool"], times=4))
        tabla<-as.data.frame(table(aux))
        poolLevels<-levels(as.factor(df_panel[,"pool"]))
        
        att_table<-lapply(1:length(poolLevels), function(i){
            att_tableP<-tabla[tabla[,"pool"] == poolLevels[i],
                c("score", "Freq")]
                
            if(any(is.na(att_tableP[,"Freq"]))){
                att_tableP[is.na(att_tableP[,"Freq"]), "Freq"]<-0
            }
            tabla <- cbind(att_tableP,cumsum(att_tableP[,"Freq"]), 
                round(100*att_tableP[,"Freq"]/sum(att_tableP[,"Freq"]),1))  
            colnames(tabla) <- c(paste(getFeature(object), "_", 
            getAttribute(object), "_intervals", sep=""),"abs","cum_abs",
                "rel")
            tabla[,"cum_rel"]<-cumsum(tabla[, "rel"])
            if(tabla[nrow(tabla),"cum_rel"] != 100 ){
                tabla[tabla[,"cum_rel"]==tabla[nrow(tabla),"cum_rel"], 
                    "cum_rel"] <-100
            }
            return(tabla)
        })
        names(att_table)<-poolLevels
        
    }else{
        att_table<-lapply(1:ncol(scores), function(j){
                
            att_table<-(as.data.frame(table(df_panel[,colnames(scores)[j]])))
            att_table<-merge(x=att_table, y=interval_names[,"interval_names", 
                drop=FALSE], by.x="Var1", by.y="interval_names", all.y=TRUE)
            att_table<-att_table[match(interval_names[,"interval_names"], 
                att_table[,"Var1"]),]
            if(any(is.na(att_table[,"Freq"]))){
                att_table[is.na(att_table[,"Freq"]), "Freq"]<-0
            }
            tabla <- cbind(att_table,cumsum(att_table[,"Freq"]),round(
                100*att_table[,"Freq"]/sum(att_table[,"Freq"]),1))  
            colnames(tabla) <- c(paste(getFeature(object), "_", 
                getAttribute(object), "_intervals", sep=""),"abs","cum_abs",
                "rel")
            tabla[,"cum_rel"]<-cumsum(tabla[, "rel"])
            if(tabla[nrow(tabla),"cum_rel"] != 100 ){
                tabla[tabla[,"cum_rel"]==tabla[nrow(tabla),"cum_rel"], 
                "cum_rel"] <-100
            }
            return(tabla)
        })
        names(att_table)<-listNames
}
    return(att_table)
})