#library(, warn.conflicts=FALSE, quietly = TRUE)

#Install the libraries
suppressPackageStartupMessages(library(httr))
suppressPackageStartupMessages(library(data.table, quietly = TRUE))
suppressPackageStartupMessages(library(dplyr, quietly = TRUE))
suppressPackageStartupMessages(library(xml2, quietly = TRUE))
suppressPackageStartupMessages(library(jsonlite, quietly = TRUE))
suppressPackageStartupMessages(library(purrr, quietly = TRUE))
suppressPackageStartupMessages(library(readr, quietly = TRUE))
suppressPackageStartupMessages(library(doParallel, quietly = TRUE))

#=======BASIC INFO ABOUT THE SmartSupp EXTRACTOR========#


#=======CONFIGURATION========#
## initialize application
 library('keboola.r.docker.application')
 app <- DockerApplication$new('/data/')

# app$readConfig()
# 
## access the supplied value of 'myParameter'
user<-app$getParameters()$user
pwd<-app$getParameters()$'#pwd'
from<-app$getParameters()$from

url<-"https://digitalengines.daktela.com"
short<-FALSE
##Catch config errors

if(is.null(pwd) | is.null(user) | is.null(url) ) stop("invalid credentials or site URL")

## Retrieve token 

token<-POST(paste0(url,"/api/v6/login.json"),body=list(password=pwd,username=user,only_token=1))%>%
  content("text",encoding = "UTF-8")%>%fromJSON(flatten=TRUE,simplifyDataFrame = TRUE)%>%.$result

#This function paginates through an endpoint in parallel and writes the result to the out bucket

write_endpoint<-function(endpoint,token,from=NULL,short=FALSE,limit=1000,iterator=FALSE){
  
  #Writing a message to the console
  write(paste0(endpoint[[3]], " extraction started at: ",a<-Sys.time()) , stdout())
  
  ## Looking wether the time filter is applied
  endpoint_url<-ifelse(is.null(from) | endpoint[[2]]==FALSE,
                       #FALSE - without filter
                       endpoint[[1]], 
                       #TRUE - with time filter
                       paste0(
                         endpoint[[1]],
                         "?filter[field]=",
                         endpoint[[2]],
                         "&filter[operator]=gte&filter[value]=",
                         from
                       ))
  
  ## Filtering example /api/v6/contacts.json?filter[field]=Time&filter[operator]=gte&filter[value]=2018-01-01
  
  #create the endpoint
  call<-paste0(url,endpoint_url)
  
  #get the size of the list
  total<-GET(call,query=list(accessToken=token,skip=0,take=1))%>%
    content("text",encoding = "UTF-8")%>%fromJSON(flatten=TRUE,simplifyDataFrame = FALSE)%>%.$result%>%.$total
  
  #continue only if size of the list >0 
  if(total<1){ 
            write(paste0("Report ",endpoint[[3]], " is empty for selected criteria "), stdout())
  } else {
  
      #register cores on the machine for the parallel loop
      registerDoParallel(cores=detectCores()-1)
  
      data<-foreach(i=seq(0,total,by = limit), .combine=bind_rows,.multicombine = TRUE,.errorhandling = "remove", .init=NULL) %dopar% {
    
      r<-GET(call,query=list(accessToken=token,skip=i,take=limit))%>%
      content("text",encoding = "UTF-8")

      if(is.function(iterator)) 
      { 
      write("processing DATA")
      
      res<-r%>%iterator%>%as_data_frame 
      }else {
      res<-r%>%fromJSON(flatten=TRUE,simplifyDataFrame = TRUE)%>%.$result%>%.$data%>%
        select(-contains("."))%>%.[,sapply(.,class)!="list"]%>%as_data_frame
      }
    
      res
    }
    csvFilePath<-paste0("/data/out/tables/",endpoint[[3]],".csv")
    write_csv(data,csvFilenPath)
    #Přidat manifest file
    app$writeTableManifest(csvFilePath,destination='')
    
    #Writing a message to the console
    b<-Sys.time()
    write(paste0(nrow(data), " rows extracted out of ",total ," task duration: ",round(difftime(b,a,units="secs")%>%as.numeric,2)," s"), stdout())
    write(paste0(endpoint[[3]], " extraction finished at: ",Sys.time()) , stdout())
  }
}

# Extraction of endpoints -------------------------------------------------

## Activities
activities<-list("/api/v6/activities.json","time","activities")
write_endpoint(activities,token,from = from,short = short)

## ActivitiesCall
activitiesCall<-list("/api/v6/activitiesCall.json","call_time","activitiesCall")

### Iterator function for Activities Call transformation

iterator_activitiesCall<-function(r){
  clean<-r%>%fromJSON(flatten=TRUE,simplifyDataFrame = TRUE)%>%.$result%>%.$data%>%select(-contains("."))%>%as_data_frame
  df<-r%>%fromJSON(flatten=FALSE,simplifyDataFrame = TRUE)%>%.$result%>%.$data
  df<-data_frame(queue=map(df,"name")$id_queue,
                  queue_title=map(df,"title")$id_queue,
                  agent_title=map(df,"title")$id_agent
                  )
  out<-clean%>%bind_cols(df)
}

write_endpoint(activitiesCall,token,from = from,short = short,iterator = iterator_activitiesCall)

## ActivitiesEmail
activitiesEmail<-list("/api/v6/activitiesEmail.json","time","activitiesEmail")

iterator_activitiesEmail<-function(r){
  clean<-r%>%fromJSON(flatten=TRUE,simplifyDataFrame = TRUE)%>%.$result%>%.$data%>%select(-contains("."))%>%as_data_frame
  df<-r%>%fromJSON(flatten=FALSE,simplifyDataFrame = TRUE)%>%.$result%>%.$data
  df<-data_frame(queue_title=map(df,"title")$queue
  )
  out<-clean%>%bind_cols(df)%>%select(-files)
}

write_endpoint(activitiesEmail,token,from = from,short = short,iterator = iterator_activitiesEmail)

## ActivitiesChat
activitiesChat<-list("/api/v6/activitiesChat.json","time","activitiesChat")

iterator_activitiesChat<-function(r){
  clean<-r%>%fromJSON(flatten=TRUE,simplifyDataFrame = TRUE)%>%.$result%>%.$data%>%select(-contains("."))%>%as_data_frame
  df<-r%>%fromJSON(flatten=FALSE,simplifyDataFrame = TRUE)%>%.$result%>%.$data
  df<-data_frame(queue_title=map(df,"title")$queue,
                 referer=map(df,"referer")$options
  )
  out<-clean%>%bind_cols(df)
}

write_endpoint(activitiesChat,token,from = from,short = short,iterator = iterator_activitiesChat)

## Accounts
accounts<-list("/api/v6/accounts.json",FALSE,"accounts")
write_endpoint(accounts,token,from = from,short = short,iterator = FALSE)

## Groups
groups<-list("/api/v6/groups.json",FALSE,"groups")
write_endpoint(groups,token,from = from,short = short,iterator = FALSE)

## Pauses
pauses<-list("/api/v6/pauses.json",FALSE,"pauses")
write_endpoint(pauses,token,from = from,short = short,iterator = FALSE)

## Queues
queues<-list("/api/v6/queues.json",FALSE,"queues")
write_endpoint(queues,token,from = from,short = short,iterator = FALSE)

## Statuses
statuses<-list("/api/v6/statuses.json",FALSE,"statuses")
write_endpoint(statuses,token,from = from,short = short,iterator = FALSE)
  
## Templates
templates<-list("/api/v6/templates.json",FALSE,"templates")
write_endpoint(templates,token,from = from,short = short,iterator = FALSE)

## Tickets
tickets<-list("/api/v6/tickets.json","edited","tickets")
write_endpoint(tickets,token,from = from,short = short,iterator = FALSE)

           
