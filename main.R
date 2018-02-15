#Install the libraries
library(httr, warn.conflicts=FALSE, quietly = TRUE)
library(data.table, warn.conflicts=FALSE, quietly = TRUE)
library(dplyr, warn.conflicts=FALSE, quietly = TRUE)
library(xml2, warn.conflicts=FALSE, quietly = TRUE)
library(jsonlite, warn.conflicts=FALSE, quietly = TRUE)
library(purrr, warn.conflicts=FALSE, quietly = TRUE)
library(readr, warn.conflicts=FALSE, quietly = TRUE)
library(doParallel, warn.conflicts=FALSE, quietly = TRUE)



#=======CONFIGURATION========#
## initialize application
library('keboola.r.docker.application')
app <- DockerApplication$new('/data/')

app$readConfig()

## access the supplied value of 'myParameter'
user<-app$getParameters()$user
pwd<-app$getParameters()$'#password'
from<-app$getParameters()$fromDate

url<-"https://digitalengines.daktela.com"

## Endpoints
endpointTemplate<-list(
  activities=list("/api/v6/activities.json","time"),
  activitiesCall=list("/api/v6/activitiesCall.json","call_time"),
  activitiesEmail=list("/api/v6/activitiesEmail.json","time"),
  activitiesChat=list("/api/v6/activitiesChat.json","time"),
  accounts=list("/api/v6/accounts.json",FALSE),
    # contacts=list("/api/v6/contacts.json","edited"),
    # crmRecords=list("/api/v6/crmRecords.json","edited"),
    # campaignRecords=list("/api/v6/campaignsRecords.json","edited"),
  groups=list("/api/v6/groups.json",FALSE),
  pauses=list("/api/v6/pauses.json",FALSE),
  queues=list("/api/v6/queues.json",FALSE),
  statuses=list("/api/v6/statuses.json",FALSE),
  templates=list("/api/v6/templates.json",FALSE),
  tickets=list("/api/v6/tickets.json","edited"),
  users=list("/api/v6/users.json",FALSE)
  )

endpointList <- lapply(endpointTemplate,
                       function(x) {
                         ifelse(
                           is.null(from) | x[[2]][1]==FALSE,
                           x[[1]][1], 
                           paste0(
                             x[[1]][1],
                             "?filter[field]=",
                             x[[2]][1],
                             "&filter[operator]=gte&filter[value]=",
                             from
                           ))})
                         
## Filtering example /api/v6/contacts.json?filter[field]=Time&filter[operator]=gte&filter[value]=2018-01-01

##Catch config errors

if(is.null(pwd) | is.null(user) | is.null(url) ) stop("invalid credentials or site URL")

## Retrieve token 

token<-POST(paste0(url,"/api/v6/login.json"),body=list(password=pwd,username=user,only_token=1))%>%
  content("text",encoding = "UTF-8")%>%fromJSON(flatten=TRUE,simplifyDataFrame = TRUE)%>%.$result

#This function paginates through an endpoint in parallel

get_endpoint<-function(endpoint_url,token,limit=1000,short=TRUE){
  
  #create the endpoint
  endpoint<-paste0(url,endpoint_url)
  
  #get the size of the list
  total<-GET(endpoint,query=list(accessToken=token,skip=0,take=1))%>%
    content("text",encoding = "UTF-8")%>%fromJSON(flatten=TRUE,simplifyDataFrame = TRUE)%>%map("total")%>%.$result
  
  #register cores on the machine for the parallel loop
  registerDoParallel(cores=detectCores()-1)
  
  data<-foreach(i=seq(0,total,by = limit), .combine=bind_rows,.multicombine = TRUE,.errorhandling = "remove", .init=NULL) %dopar% {
    
    r<-GET(endpoint,query=list(accessToken=token,skip=i,take=limit))%>%
        content("text",encoding = "UTF-8")%>%fromJSON(flatten=TRUE,simplifyDataFrame = TRUE)%>%map_df("data")%>%select(-contains("."))%>%
        .[,lapply(.,class)!="list"]
    
    r}%>%distinct 
  
}


###this functions loops all the endpoints and retrieves all the data

loop_endpoints<-function(endpointList,token,short=TRUE){
  data<-lapply(endpointList,function(x)get_endpoint(x,token))
}

data<-loop_endpoints(endpointList,token)

#check empty frames
index<-map(data,length)>0

registerDoParallel(cores=detectCores()-1)

foreach(i=which(index)) %dopar% {
write.csv(data[i],paste0("/data/in/tables/",names(endpointList[i]),".csv"),row.names = FALSE)
               
