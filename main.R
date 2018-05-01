# Libraries ---------------------------------------------------------------

## API calls with R
suppressPackageStartupMessages(library(httr))
## Data wrangling - equivalent to pandas + piping
suppressPackageStartupMessages(library(dplyr, quietly = TRUE))
suppressPackageStartupMessages(library(data.table, quietly = TRUE))
## Json parsinf (fromJson)
suppressPackageStartupMessages(library(jsonlite, quietly = TRUE))
## Functional programming - map, reduce functions
suppressPackageStartupMessages(library(purrr, quietly = TRUE))
## Reading and writing CSV files and other formats (--ditch this if ff solves the problem)
suppressPackageStartupMessages(library(readr, quietly = TRUE))
## Operations with dates
suppressPackageStartupMessages(library(lubridate, quietly = TRUE))
## string manipulation
suppressPackageStartupMessages(library(stringr, quietly = TRUE))

# Input config ------------------------------------------------------------

## initialize keboola application this saves all user inputs from the extractor to variables
 library('keboola.r.docker.application')
 app <- DockerApplication$new('/data/')

 app$readConfig()

 ## Daktela username
 user<-app$getParameters()$user
 ## Daktela password
 pwd<-app$getParameters()$'#pwd'
 ## Daktela server url
 server<-app$getParameters()$server
 ## The date
 days_past<-app$getParameters()$from
 ## Incremental load
 increment<-app$getParameters() $incremental

url<-paste0("https://",server,".daktela.com")

# Init --------------------------------------------------------------------

## Prefix
prefix<-ifelse(server=="","",paste0(server,"_"))

## Create the date from where we take data
days_past<-ifelse(is.null(days_past),1,as.numeric(days_past))

from<-Sys.Date()-days_past

##Catch config errors
if(is.null(pwd) | is.null(user) | is.null(url) ) stop("invalid credentials or site URL")

## Retrieve token
token<-POST(paste0(url,"/api/v6/login.json"),body=list(password=pwd,username=user,only_token=1))%>%
  content("text",encoding = "UTF-8")%>%fromJSON(flatten=TRUE,simplifyDataFrame = TRUE)%>%.$result

# Function definition -----------------------------------------------------

## Sanitize - This function makes sure that the results have always the same columns
sanitize<-function(res,names_unique,df_name){
  missing_cols<-dplyr::setdiff(names_unique,names(res))
  if(!is_empty(missing_cols)){
    #write(paste0("Colum ",missing_cols, " is missing, inserting null values"), stdout())
    res[,missing_cols]<-""
  }
  
  index<-names_unique[names(names_unique)=="key"]
#If the prefix is set this will rewrite all the key columns to make sure they have the prefix in the index
  if(prefix!=""){
  res<-res %>% 
    select(index) %>% 
    mutate_all(function(x){ x<-paste0(prefix,x)}) %>% 
    cbind(.,res[setdiff(names_unique,index)])
  }
  
  res<-res%>%select(names_unique)
  
  if(prefix!=""){ res<-res%>%mutate(server=server)}
  if(df_name %in% c("activitiesChat","activitiesEmail","activitiesCall")){ res<-res%>%rename(activities_name=name)}
  
  res
  
}

## This function takes a field list and converts it to a Daktela API Call
#?fields[0]=firstname&fields[1]=lastname&fields[2]=account.title

get_fields<-function(fields){

  elements<-map2_chr(fields,seq_along(fields)-1, function(x,y){ paste0("fields[",y,"]=",x) })
  string=paste0(elements, collapse = "&")

}

#' Parse
#' Default parser for the JSON response of the Daktela API


write_endpoint<-function(endpoint,token,from=NULL,limit=1000){

  #Record task start time
  a<-Sys.time()

  #Hardcode the fields to return
  #&filter[field]=firstname&filter[operator]=eq&filter[value]=John
  filter<-ifelse(endpoint[[5]]==FALSE,'',endpoint[[5]])

  fields<-map2_chr(endpoint[[4]],seq_along(endpoint[[4]])-1, function(x,y){ paste0("fields[",y,"]=",x) })%>%
          paste0(collapse = "&")%>%
          paste0(filter)

  ## Looking wether the time filter is applied and changing the endpoint url accordingly
  endpoint_url<-if_else(is.null(from) | endpoint[[2]]==FALSE,
                        #FALSE - without filter
                        endpoint[[1]]%>%paste0("?",fields),
                        #TRUE - with time filter
                        paste0(endpoint[[1]],"?filter[0][field]=",endpoint[[2]],"&filter[0][operator]=gte&filter[0][value]=",from)%>%
                        paste0("&",fields))

  ## Filtering example /api/v6/contacts.json?filter[field]=Time&filter[operator]=gte&filter[value]=2018-01-01&fields[0]=ticket

  #create the endpoint url
  call<-paste0(url,endpoint_url)

  #get the size of the list
  total<-GET(call,query=list(accessToken=token,skip=0,take=1))%>%
    content("text",encoding = "UTF-8")%>%fromJSON(flatten=TRUE,simplifyDataFrame = FALSE)%>%.$result%>%.$total

  #continue only if size of the list >0
  if(total<1){
    write(paste0("Report ",endpoint[[3]], " is empty for selected criteria "), stderr())
    rows_fetched<-0
    res<-setNames(data.frame(matrix(ncol = length(endpoint[[4]]) , nrow = 0)), endpoint[[4]])
    #If i = 0 then initialize the file else append the csv using fwrite from data.table in order to not waste RAM
    fwrite(res,paste0("/data/out/tables/",prefix,endpoint[[3]],".csv"),append = FALSE, sep=",", sep2=c("{","|","}"))

  } else {

    #creating a sequence reflecting pagination limits
   i=seq(0,total,by = limit)

    rows_fetched<-map(i,function(i){
      #Call the api
      tryCatch(
        {
          res<-GET(call,query=list(accessToken=token,skip=i%>%as.integer,take=limit))%>%
            #Return the json
            content("text",encoding = "UTF-8")%>%
            #Use the parse function
            fromJSON(flatten = TRUE, simplifyDataFrame = TRUE) %>%
            .$result%>%.$data%>%as_data_frame%>%sanitize(endpoint[[4]],endpoint[[3]])

          #If i = 0 then initialize the file else append the csv using fwrite from data.table in order to not waste RAM
          fwrite(res,paste0("/data/out/tables/",prefix,endpoint[[3]],".csv"),append = ifelse(i>0,TRUE,FALSE), sep=",", sep2=c("{","|","}"))

          cnt<-nrow(res) },
        error=function(e){print(paste0("iteration: ",as.integer(i)%>%as.character, "failed. Error: ",message(e))); return(0)})

    })%>%unlist%>%as.numeric%>%sum()
  
  #Writing a message to the console
  b<-Sys.time()
  write(paste0("Task ",endpoint[[3]],": ",rows_fetched ,"/",total," records extracted, task duration: ",time<-round(difftime(b,a,units="secs")%>%as.numeric,2)," s"), stdout())

#--------------------------------------------------addition for Keboola extractor------------------
    if (endpoint[[3]]=="activitiesCall") {
           app$writeTableManifest(paste0("/data/out/tables/",endpoint[[3]],".csv"),destination='', primaryKey='',incremental=TRUE)
   } else if (endpoint[[3]]=="activites") {
           app$writeTableManifest(paste0("/data/out/tables/",endpoint[[3]],".csv"),destination='', primaryKey=c('name'),incremental=TRUE)
    	}
    else if (endpoint[[3]]=="activitiesChat"|endpoint[[3]]=="activitiesEmail") {
           app$writeTableManifest(paste0("/data/out/tables/",endpoint[[3]],".csv"),destination='', primaryKey=c('item_name
'),incremental=TRUE)
    	}
     else {
          app$writeTableManifest(paste0("/data/out/tables/",endpoint[[3]],".csv"),destination='', primaryKey='',incremental= FALSE)
         }
#---------------------------------------------------------------------------------

  #Process log info
  ## Check if out_log.csv exists
  logfile_created<-file.exists("/data/out/tables/out_log.csv")

  log<-data_frame("date"=Sys.time(),"endpoint"=endpoint[[3]],"exported_records"=total,"extraction_time"=time)
  fwrite(log,paste0("/data/out/tables/",prefix,"log.csv"),append=logfile_created)
}
  app$writeTableManifest("/data/out/tables/out_log.csv",destination='', primaryKey=c('date','endpoint'), incremental=TRUE)

  # ## Accounts) ------------------------------------------------------------

names_accounts<-c( key="name",
                  "title",
                  "survey",
                  "description",
                  "deleted"
                  )

accounts<-list("/api/v6/accounts.json",FALSE,"accounts",names_accounts,FALSE)

write_endpoint(accounts,token,from = from)

# ## Users) ------------------------------------------------------------

names_users<-c( key="name",
               "title",
               "description",
               "algo",
               "email",
               "nps_score",
               "backoffice_user",
               "deleted" )

users<-list("/api/v6/users.json",FALSE,"users",names_users,FALSE)

write_endpoint(users,token,from = from)

# ## Groups ---------------------------------------------------------------

names_groups<-c(key="name",
                "title",
                "description",
                "type",
                "deleted")
groups<-list("/api/v6/groups.json",FALSE,"groups",names_groups,FALSE)

write_endpoint(groups,token,from = from)


# ## Pauses ---------------------------------------------------------------

names_pauses<-c(key="name",
                "title",
                "paid",
                "type",
                "max_duration",
                "calculated_from",
                "auto_pause",
                "deleted")

pauses<-list("/api/v6/pauses.json",FALSE,"pauses",names_pauses,FALSE)

write_endpoint(pauses,token,from = from)


# ## Queues ---------------------------------------------------------------

names_queues<-c(key="name",
                "title",
                "description",
                "type",
                "direction",
                "deactivated",
                "deleted",
                "usersCount" )

queues<-list("/api/v6/queues.json",FALSE,"queues",names_queues,FALSE)

write_endpoint(queues,token,from = from)


# ## Statuses -------------------------------------------------------------

names_statuses<-c(key="name",
                  "title",
                  "validation",
                  "nextcall",
                  "blacklist_database",
                  "blacklist_expiration_time",
                  "color",
                  "deleted")

statuses<-list("/api/v6/statuses.json",FALSE,"statuses",names_statuses,FALSE)

write_endpoint(statuses,token,from = from)


# ## Templates ------------------------------------------------------------

names_templates<-c(key="name",
                   "title",
                   "description",
                   "format",
                   "usingtype",
                   "content",
                   "deleted",
                   "id_template"
                   )

templates<-list("/api/v6/templates.json",FALSE,"templates",names_templates,FALSE)

write_endpoint(templates,token,from = from)




# ## Tickets --------------------------------------------------------------

names_tickets<-c(key="name",
                 "title",
                 "email",
                 "description",
                 "stage",
                 "priority",
                 "sla_deadtime",
                 "sla_change",
                 "sla_notify",
                 "sla_duration",
                 "sla_custom",
                 "survey",
                 "survey_offered",
                 "satisfaction",
                 "satisfaction_comment",
                 "reopen",
                 "deleted",
                 "created",
                 "edited",
                 "first_answer",
                 "first_answer_duration",
                 "closed",
                 "unread",
                 "has_attachment",
                 "isBookmarked")

tickets<-list("/api/v6/tickets.json","edited","tickets",names_tickets,FALSE)

write_endpoint(tickets,token,from = from)

# ## Activities --------------------------------------------------------------

names_activities <-
  c(key="name",
    "time",
    key="ticket.name",
    key="queue.name",
    key="user.name",
    key="contact.name",
    "title",
    "action",
    "type",
    "survey",
    "record",
    "priority",
    "description",
    "time_wait",
    "time_open",
    "time_close",
    "important",
    "status"
  )



activities<-list("/api/v6/activities.json","time","activities",names_activities,FALSE)
write_endpoint(activities,token,from = from)


# Items - filtered from Activities ----------------------------------------


## ActivitiesCall
names_activitiesCall <-
  c(
    key="name",
    "time",
    key="item.id_call" ,
    "item.call_time",
    "item.direction",
    "item.answered",
    "item.clid",
    key="item.prefix_clid_name",
    "item.did",
    "item.waiting_time",
    "item.ringing_time",
    "item.hold_time",
    "item.duration",
    "item.orig_pos",
    "item.position",
    "item.disposition_cause",
    "item.disconnection_cause",
    "item.pressed_key",
    "item.missed_call",
    "item.missed_call_time",
    "item.attempts",
    "item.score",
    "item.note"
  )

activitiesCall<-list("/api/v6/activities.json","time","activitiesCall",names_activitiesCall,"&filter[1][field]=type&filter[1][operator]=eq&filter[1][value]=CALL")

write_endpoint(activitiesCall,token,from = from)

## ActivitiesEmail

names_activitiesEmail <-
  c(key="name",
    "time",
    key="item.name",
    "item.address",
    "item.direction",
    "item.wait_time",
    "item.duration",
    "item.answered",
    "item.text",
    "item.time",
    "title"
  )


activitiesEmail<-list("/api/v6/activities.json","time","activitiesEmail",names_activitiesEmail,"&filter[1][field]=type&filter[1][operator]=eq&filter[1][value]=EMAIL")

write_endpoint(activitiesEmail,token,from = from)

## ActivitiesChat
names_activitiesChat <-
  c(
    key="name",
    "time",
    "item.title",
    "item.email",
    "item.wait_time",
    "item.duration",
    "item.answered",
    "item.disconnection",
    "item.time",
    key="item.name",
    "item.ip",
    "item.country_code",
    "item.country_name",
    "item.region_code",
    "item.region_name",
    "item.city",
    "item.zip_code",
    "item.time_zone",
    "item.latitude",
    "item.longitude",
    "item.metro_code",
    "item.queue_title",
    "item.referer"
  )

activitiesChat<-list("/api/v6/activities.json","time","activitiesChat",names_activitiesChat,"&filter[1][field]=type&filter[1][operator]=eq&filter[1][value]=CHAT")

write_endpoint(activitiesChat,token,from = from)
