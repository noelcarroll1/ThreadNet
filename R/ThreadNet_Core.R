##########################################################################################################
# THREADNET:  Core functions

# This software may be used according to the terms provided in the
# GNU General Public License (GPL-3.0) https://opensource.org/licenses/GPL-3.0?
# Absolutely no warranty!
##########################################################################################################


# These are the basic functions that convert threads to networks, etc.

#' @title Converts threads to network
#' @description  Converts a sequentially ordered streams of ;events (threads) and creates a unimodal, unidimensional network.
#' Sequentially adjacent pairs of events become edges in the resulting network.
#' @name threads_to_network_original
#' @param et dataframe containing threads
#' @param TN name of column in dataframe that contains a unique thread number for each thread
#' @param CF name of the column in dataframe that contains the events that will form the nodes of the network
#' @param grp grouping variable for coloring the nodes
#' @return a list containing two dataframes, one for the nodes (nodeDF) and one for the edges (edgeDF)
#' @export threads_to_network_original
# here is a version without all the position stuff, which should be separated out, if possible.
# Added in the "group" for the network graphics - default group is 'threadNum' because it will always be there
threads_to_network_original <- function(et,TN,CF,grp='threadNum'){

    # print(head(et))
    #
    # print(paste('CF=', CF))
    # print(paste('grp=', grp))

  # First get the node names & remove the spaces
  node_label = levels(factor(et[[CF]]))  # unique(et[[CF]])
  node_label=str_replace_all(node_label," ","_")
  nNodes = length(node_label)

    # print("node_label")
    # print(node_label)
    # print(paste('nNodes=', nNodes))

  node_group=character()
  for (n in 1:nNodes){
    node_group = c(node_group, as.character(unlist( et[which(et[[CF]]==node_label[n]),grp][1]) ) )
  }

  # set up the data frames we need to draw the network
  nodes = data.frame(
    id = 1:length(node_label),
    label = node_label,
    Group = node_group,
    title=node_label)

  # get the 2 grams for the edges
  ngdf = count_ngrams(et,TN, CF, 2)

  # Adjust the frequency of the edges to 0-1 range
  ngdf$freq = round(ngdf$freq/max(ngdf$freq),3)

  # need to split 2-grams into from and to
  from_to_str = str_split(str_trim(ngdf$ngrams), " ", n=2)

  # need to find a better way to do this...
  nEdges = length(from_to_str)
  from_labels=matrix(data="", nrow=nEdges,ncol=1)
  to_labels =matrix(data="", nrow=nEdges,ncol=1)
  from=integer(nEdges)
  to=integer(nEdges)
  for (i in 1:length(from_to_str)){

    # Get from and to by spliting the 2-gram
    from_labels[i] = str_split(from_to_str[[i]]," ")[1]
    to_labels[i] = str_split(from_to_str[[i]]," ")[2]

    # use match to lookup the nodeID from the label...
    from[i] = match(from_labels[i], nodes$label)
    to[i] = match(to_labels[i], nodes$label)
  }

  edges = data.frame(
    from,
    to,
    label = ngdf$freq,
    Value =ngdf$freq) %>% filter(!from==to)

  # print(paste("T2N nodes:",nodes))
  #  print(paste("T2N edges:",edges))

  return(list(nodeDF = nodes, edgeDF = edges))
}

# threads_to_network_with_positions <- function(et,TN,CF,timesplit){
#   et$time = et[[timesplit]]
#   #et$time = et$POVseqNum
#
#   #et$time<-as.numeric(et$tStamp)
#   # First get the node names & remove the spaces
#   node_label = unique(et[[CF]])
#   node_label=str_replace_all(node_label," ","_")
#
#   # print("node_label")
#   # print(node_label)
#
#   # set up the data frames we need to draw the network
#   nodes = data.frame(
#     id = 1:length(node_label),
#     label = node_label,
#     title=node_label)
#
#   node_position_y = data.frame(table(et[[CF]]))
#   colnames(node_position_y) <- c('label', 'y_pos')
#   node_position_x = aggregate(et$time, list(et[[CF]]), mean)
#   colnames(node_position_x) <- c('label', 'x_pos')
#
#   nodes = merge(nodes, node_position_y, by=c("label"))
#   nodes = merge(nodes, node_position_x, by=c("label"))
#
#   # get the 2 grams for the edges
#   ngdf = count_ngrams(et,TN, CF, 2)
#
#   # need to split 2-grams into from and to
#   from_to_str = str_split(str_trim(ngdf$ngrams), " ", n=2)
#
#   # need to find a better way to do this...
#   nEdges = length(from_to_str)
#   from_labels=matrix(data="", nrow=nEdges,ncol=1)
#   to_labels =matrix(data="", nrow=nEdges,ncol=1)
#   from=integer(nEdges)
#   to=integer(nEdges)
#   for (i in 1:length(from_to_str)){
#
#     # Get from and to by spliting the 2-gram
#     from_labels[i] = str_split(from_to_str[[i]]," ")[1]
#     to_labels[i] = str_split(from_to_str[[i]]," ")[2]
#
#     # use match to lookup the nodeID from the label...
#     from[i] = match(from_labels[i], nodes$label)
#     to[i] = match(to_labels[i], nodes$label)
#   }
#
#   edges = data.frame(
#     from,
#     to,
#     label = paste(ngdf$freq)
#   )
#
#   edges = merge(edges, nodes[,c('id', 'y_pos', 'x_pos')], by.x=c('from'), by.y=c('id'))
#   edges = merge(edges, nodes[,c('id', 'y_pos', 'x_pos')], by.x=c('to'), by.y=c('id'))
#   colnames(edges)<-c('from', 'to', 'label', 'from_y', 'from_x', 'to_y', 'to_x')
#   return(list(nodeDF = nodes, edgeDF = edges))
# }


#' @title Counts ngrams in a set of threads
#' @description Counting ngrams is essential to several ThreadNet functions. This function counts n-grams within threads where the length of the thread is greater than n.
#' @name count_ngrams
#' @param o dataframe containing threads
#' @param TN name of column in dataframe that contains a unique thread number for each thread
#' @param CF name of the column in dataframe that contains the events that will form the nodes of the network
#' @param n length of ngrams to count
#' @return a dataframe with ngram, frequency and proportion in descending order
#' @export
count_ngrams <- function(o,TN,CF,n){

  # Need a vector of strings, one for each thread, delimited by spaces
  # the function long_enough filters out the threads that are shorter than n
  # use space for the delimiter here
  text_vector = long_enough( thread_text_vector(o,TN,CF,' '), n, ' ')

  # print("text_vector")
  # print(text_vector)

  ng = get.phrasetable(ngram(text_vector,n))

  # add a column here for the length of the ngram -- useful later!
  ng$len = n

  return(ng)
}


#################################################################
#' @title Converts occurrences into events, make threads from a new POV
#' @description Take the raw occurrences from the input file and sort them by time stamp within
#' a set of contextual factors that remain constant for each thread.
#' @name ThreadOccByPOV
#' @param  o is the dataframe of cleaned ocurrences
#' @param  THREAD_CF is a list of 1 or more context factors that define the threads (and stay constant during each thread)
#' @param  EVENT_CF is a list of 1 or more context factors that define events (and change during threads)
#' @return dataframe containing the same occurrences sorted from a different point of view
#' @export
ThreadOccByPOV <- function(o,THREAD_CF,EVENT_CF){

  timescale = get_timeScale()

  withProgress(message = "Creating Events", value = 0,{

    n = 5

    # make sure there is a value
    if (length(THREAD_CF) == 0 | length(EVENT_CF)==0){return(data.frame())}

    incProgress(1/n)

    # Sort by POV and timestamp. The idea is to get the stream of activities from
    # a particular point of view (e.g., actor, location, etc.)
    # add the new column that combines CFs, if necessary

    # get a new column name based on the thread_CF -- use this to define threads
    nPOV = newColName(THREAD_CF)
    occ = combineContextFactors(o,THREAD_CF, nPOV )

    # print("nPOV")
    # print(nPOV)
    #
    # print("THREAD_CF")
    # print(THREAD_CF)

    # The event context factors define the new category of events within those threads
    occ = combineContextFactors(occ,EVENT_CF,newColName(EVENT_CF))
    occ = occ[order(occ[nPOV],occ$tStamp),]

    # add two columns to the data frame
    occ$threadNum = integer(nrow(occ))
    occ$seqNum =   integer(nrow(occ))

    # add new column called label - just copy the new combined event_CF column
    occ$label = occ[[newColName(EVENT_CF)]]


    # occurrences have zero duration
    occ$eventDuration = 0

    # Also add columns for the time gapsthat appear from this POV
    occ$timeGap  =  diff_tStamp(occ$tStamp)


    # create new column for relative time stamp. Initialize to absolute tStamp and adjust below
    occ$relativeTime = lubridate::ymd_hms(occ$tStamp)

    # then get the unique values in that POV
    occ[nPOV] = as.factor(occ[,nPOV])
    pov_list = levels(occ[[nPOV]])

    incProgress(2/n)

    # now loop through the pov_list and assign values to the new columns
    start_row=1
    thrd=1
    for (p in pov_list){

      # get the length of the thread
      tlen = sum(occ[[nPOV]]==p)


      # print(paste('start_row=',start_row))
      # print(paste('thrd =', thrd ))
      # print(paste('p =', p ))
      # print(paste('tlen =', tlen ))

      # guard against error
      if (length(tlen)==0) tlen=0
      if (tlen>0){

        #compute the index of the end row
        end_row = start_row+tlen-1
        # print(paste('start_row =', start_row ))
        # print(paste('end_row =',end_row  ))

        # they all get the same thread number and incrementing seqNum
        occ[start_row:end_row, "threadNum"] <- as.matrix(rep(as.integer(thrd),tlen))
        occ[start_row:end_row, "seqNum"] <- as.matrix(c(1:tlen))


        # find the earliest time value for this thread
        start_time = min(lubridate::ymd_hms(occ$tStamp[start_row:end_row]))
        # print(start_time)

        # increment the counters for the next thread
        start_row = end_row + 1
        thrd=thrd+1
      } # tlen>0
    } # p in povlist

    incProgress(3/n)

    # split occ data frame by threadNum to find earliest time value for that thread
    # then substract that from initiated relativeTime from above
     occ_split = lapply(split(occ, occ$threadNum),
                          # function(x) {x$relativeTime = x$relativeTime - min(lubridate::ymd_hms(x$tStamp)); x})
              function(x) {x$relativeTime = difftime(x$relativeTime,  min(lubridate::ymd_hms(x$tStamp)), units=timescale ); x})

    # # row bind data frame back together
     occ= data.frame(do.call(rbind, occ_split))

    #  these are just equal to the row numbers -- one occurrence per event
    occ["occurrences"] =   1:nrow(occ)


    # now go through and change each of the CF values to a vector (0,0,0,1,0,0,0,0)
    for (cf in EVENT_CF){
      #make a new column for each CF
      VCF = paste0("V_",cf)
      occ[[VCF]]= vector(mode = "integer",length=nrow(occ))

      for (r in 1:nrow(occ)){
        occ[[r,VCF]] = list(convert_CF_to_vector(occ,cf,r))
      }
    }

    incProgress(4/n)


    #  return events with network cluster added for zooming...
    # print('assign label to ZM_1')
    # e$ZM_1 = e$label
     e=clusterEvents(occ, '', 'Network Proximity', THREAD_CF, EVENT_CF,'threads')

    # sort them by threadnum and seqnum
    e = e[order(e[['threadNum']],e[['seqNum']]),]

    incProgress(5/n)

  } )  # with progress...


  # for debugging, this is really handy
#   save(occ,e,file="O_and_E_1.rdata")

print('done converting occurrences...')


  return( e )

}


##############################################################################################################
#' @title Maps occurrences into events by chunks.
#' @description Thus function provides a way to map occurrences into events, so is is not necessary to interpret individual
#' occurrences in isolation.  Provides three ways to accomplish this mapping.
#' @name  OccToEvents_By_Chunk
#' @param  o  a dataframe of occurrences
#' @param m = method parameter = one of c('Variable chunks','Uniform chunks')
#' @param EventMapName = used to store this mapping for visualization and comparison
#' @param uniform_chunk_size = used to identify breakpoints -- from input slider
#' @param tThreshold = used to identify breakpoints -- from input slider
#' @param timescale hours, min or sec
#' @param chunk_CF - context factors used to delineate chunks
#' @param thread_CF - context factors used to delineate threads
#' @param event_CF - context factors used to define events
#' @param compare_CF = context factors used for comparison -- need to be copied over here when the thread is created.
#' @return event data frame, with occurrences aggregated into events.
#' @export
OccToEvents_By_Chunk <- function(o, m, EventMapName, uniform_chunk_size, tThreshold, timescale='mins', chunk_CF, thread_CF, event_CF, compare_CF){

  # Only run if eventMapName is filled in
  if (EventMapName =="") {return(data.frame()) }


  # put this here for now
 # timescale='mins'
  timescale=get_timeScale()

  #### First get the break points between the events
 # Ideally, these should operate WITHIN each thread, not on the whole set of occurrences...
  # Add RLE -- consecutive runs -- as a way to chunk -- let user pick the CFs
  # very similar to the changes algorithm...
# choices = c( "Changes", "Time Gap","Fixed Size"),
  if (m=="Changes"){
    o$handoffGap =  diff_handoffs(o[chunk_CF])
    breakpoints = which(o$handoffGap == 0)
  } else if (m=="Time Gap") {
    breakpoints = which(o$timeGap > tThreshold)
  } else if (m=="Fixed Size") {
    breakpoints = seq(1,nrow(o),uniform_chunk_size)
  }


  # Grab the breakpoints from the beginning of the threads as well
  threadbreaks = which(o$seqNum == 1)
  breakpoints = sort(union(threadbreaks,breakpoints))

  # print(breakpoints)

  ### Use the break points to find the chunks -- just store the index back to the raw data
  nChunks = length(breakpoints)

  # print(paste("nChunks=",nChunks))

  # make the dataframe for the results.  This is the main data structure for the visualizations and comparisons.
  e = make_event_df(event_CF, compare_CF, nChunks)
  e$label = as.character(e$label)

  #  need to create chunks WITHIN threads.  Need to respect thread boundaries
  # take union of the breakpoints, plus thread boundaries, plus 1st and last row

  # counters for assigning thread and sequence numbers
  thisThread=1  # just for counting in this loop
  lastThread=0
  seqNo=0  # resets for each new thread

  for (chunkNo in 1:nChunks){

    # Chunks start at the current breakpoint
    start_idx=breakpoints[chunkNo]

    # Chunks end at the next breakpoint, minus one
    # for the last chunk,the stop_idx is the last row
    if (chunkNo < nChunks){
      stop_idx = breakpoints[chunkNo+1] - 1
    } else if (chunkNo==nChunks){
      stop_idx = nrow(o)
    }

    # assign the occurrences
    e$occurrences[chunkNo] = list(start_idx:stop_idx)

    e$label[chunkNo] = paste0('<',
                                str_replace_all(concatenate(o$label[start_idx:stop_idx]), ' ','++'),
                                '>')

    # assign timestamp and duration
    e$tStamp[chunkNo] = parse_date_time(o$tStamp[start_idx], c("dmy HMS", "dmY HMS", "ymd HMS"))

    e$eventDuration[chunkNo] = difftime(o$tStamp[stop_idx], o$tStamp[start_idx],units=timescale )

    # copy in the threadNum and assign sequence number
    e$threadNum[chunkNo] = o$threadNum[start_idx]
    thisThread = o$threadNum[start_idx]


    # fill in data for each of the context factors
    for (cf in compare_CF){
      e[chunkNo,cf] = as.character(o[start_idx,cf])
    }

    for (cf in event_CF){
      VCF = paste0("V_",cf)
      e[[chunkNo, VCF]] = list(aggregate_VCF_for_event(o,e$occurrences[chunkNo],cf ))
    }

    # Advance or reset the seq counters
    if (thisThread == lastThread){
      seqNo = seqNo +1
    } else if (thisThread != lastThread){
      lastThread = thisThread
      seqNo = 1
    }
    e$seqNum[chunkNo] = seqNo

  }

  # convert them to factors
  for (cf in compare_CF){
    e[cf] = as.factor(e[,cf])
  }

  # fill in the last column with the label (tried using row number...)
#  e$ZM_1 = as.factor(e$label)
#  e$ZM_1 = 1:nrow(e)

  # sort them by threadnum and seqnum
  e = e[order(e[['threadNum']],e[['seqNum']]),]

  # split data frame by threadNum to find earliest time value for that thread
  # then substract that from initiated relativeTime from above
 # e$relativeTime = lubridate::ymd_hms(e$tStamp)
  e$relativeTime = parse_date_time(e$tStamp, c("dmy HMS", "dmY HMS", "ymd HMS"))

   e_split = lapply(split(e, e$threadNum),
                    function(x) {x$relativeTime = difftime(x$relativeTime,  min(lubridate::ymd_hms(x$tStamp)), units=timescale ); x})
                     # function(x) {x$relativeTime = x$relativeTime - min(lubridate::ymd_hms(x$tStamp)); x})
  # # # row bind data frame back together
   e= data.frame(do.call(rbind, e_split))


  # print(head(e))
  # this will store the event map in the GlobalEventMappings and return events with network cluster added for zooming...
  e=clusterEvents(e, EventMapName, 'Contextual Similarity', thread_CF, event_CF,'POV')


  # store the POV in the GlobalEventMappings
  store_POV(EventMapName, e, thread_CF, event_CF)

  # for debugging, this is really handy
  #  save(o,e,file="O_and_E_2.rdata")

  return(e)

}


################################################################################
#' @title OccToEvents3
#' @description Creates events based on frequent ngrams or regular expressions
#' @name OccToEvents3
#' @param  o  a dataframe of occurrences
#' @param EventMapName = used to store this mapping for visualization and comparison
#' @param THREAD_CF - context factors used to delineate threads
#' @param EVENT_CF - context factors used to define events
#' @param compare_CF = context factors used for comparison -- need to be copied over here when the thread is created.
#' @param TN ThreadNum
#' @param CF context factor
#' @param rx list of patterns
#' @param KeepIrregularEvents = keep or drop events that don't fit patterns
#' @return event data frame, with occurrences aggregated into events.
#' @export
OccToEvents3 <- function(o, EventMapName, THREAD_CF, EVENT_CF, compare_CF,TN, CF, rx, KeepIrregularEvents){

  # print(rx)

  # Only run if eventMapName is filled in
  if (EventMapName =="") {return(data.frame()) }

  # keep track of the length of each pattern
  for (i in 1:nrow(rx))
  {rx$patLength[i] = length(unlist(strsplit(rx$pattern[i], ',')))
  }

  # print(rx)
  # print(rx$label)

  # get the time scale
  timescale=get_timeScale()


  # get the text vector for this set of threaded occurrences, delimited by commas
  tv = thread_text_vector( o, TN, CF, ',' )

  # apply regex to tv and split on the commas
  tvrx =  replace_regex_list( tv, rx )

  tvrxs = lapply(1:length(tvrx), function(i) {unlist(strsplit(tvrx[[i]],','))})

  # print('tvrx')
  # print(tvrx[1:3])
  # print('tvrxs')
  # print(tvrxs[1:3])

  # count the total number of chunks
  nChunks = length(unlist(tvrxs))

  # make the dataframe for the results.  This is the main data structure for the visualizations and comparisons.
  e = make_event_df(EVENT_CF, compare_CF, nChunks)
  e$label = as.character(e$label)

  # # for debugging, this is really handy
  # save(o,rx,tvrxs, file="O_and_E_3.rdata")


  #loop through the threads and fill in the data for each event
  # when it's a row number in the input data array, just copy the row
  # when it's one of the regex labels, use the numbers in the pattern to compute V_ for the new event
  chunkNo=0
  original_row=0
  for (thread in 1:length(tvrxs)){

    # the events stay in sequence
    for (sn in 1:length(tvrxs[[thread]])){

      # increment the current row numbers
      chunkNo = chunkNo+1
      original_row=original_row+1

      # print(paste("original_row=",original_row))

      # assign the thread and sequence number
      e$threadNum[chunkNo] = thread
      e$seqNum[chunkNo] = sn

      # Make sure the CFs are factors
      for (cf in compare_CF){
        e[[chunkNo, cf]] =  o[[original_row, cf]]
      }

      # this is a chunk that matched one of the patterns
      if (tvrxs[[thread]][sn] %in% rx$label ){

        # print(paste('thread sn = ',thread, sn))
        # print(paste('matched regex label',tvrxs[[thread]][sn]))

        # Use the ZM_1 column to store the new labels
        e$ZM_1[chunkNo] = tvrxs[[thread]][sn]
        e$label[chunkNo] =  tvrxs[[thread]][sn]

        # need to locate the unique for from the o dataframe and aggregate those V_cf values.
        rxLen = rx$patLength[which( rx$label==tvrxs[[thread]][sn])]
        e$occurrences[[chunkNo]] = list(seq(original_row,original_row+rxLen-1,1))

        original_row = original_row + rxLen-1
        # compute the V_ based on the occurrences
        for (cf in EVENT_CF){
          VCF = paste0("V_",cf)
          e[[chunkNo, VCF]] = list(aggregate_VCF_for_regex(o,e$occurrences[chunkNo],cf ))
        }

        # assign timestamp and duration -- use first - last occurrence times
        # e$eventDuration[chunkNo] = difftime(o$tStamp[stop_idx], o$tStamp[start_idx],units=timescale )
        e[[chunkNo,'tStamp']] = o[[original_row,'tStamp']]

      }
      else if (KeepIrregularEvents=='Keep') {
        # copy data from input structure
        # print(paste('no match',tvrxs[[thread]][sn]))


        # Use the ZM_1 column to store the new labels
        e$ZM_1[chunkNo] = tvrxs[[thread]][sn]
        e$label[chunkNo] =  tvrxs[[thread]][sn]
        e$occurrences[[chunkNo]] = original_row

        # copy the rest of the data
        for (cf in EVENT_CF){
          VCF = paste0("V_",cf)
          e[[chunkNo, VCF]] =  o[[original_row, VCF]]
        }

        e[[chunkNo,'tStamp']] = o[[original_row,'tStamp']]
        e[[chunkNo,'eventDuration']] = o[[original_row,'eventDuration']]

      }

    } # sn loop
  } # thread loop


  # take out the irregular events (empty rows) if so desired
  if (KeepIrregularEvents=='Drop'){
    # keep the subset where the event is not blank
    e=subset(e, !ZM_1=='')
    }

  # sort them by threadnum and seqnum
  e = e[order(e[['threadNum']],e[['seqNum']]),]

  # split data frame by threadNum to find earliest time value for that thread
  # then substract that from initiated relativeTime from above
  e$relativeTime = lubridate::ymd_hms(e$tStamp)
  e_split = lapply(split(e, e$threadNum),
                   function(x) {x$relativeTime = difftime(x$relativeTime,  min(lubridate::ymd_hms(x$tStamp)), units=timescale ); x})
                   # function(x) {x$relativeTime = x$relativeTime - min(lubridate::ymd_hms(x$tStamp)); x})

  # # row bind data frame back together
  e= data.frame(do.call(rbind, e_split))

  # # for debugging, this is really handy
  #   save(o,e,rx,tvrxs, file="O_and_E.rdata")

    # store the POV in the GlobalEventMappings
    store_POV(EventMapName, e, THREAD_CF, EVENT_CF)

    return(e)

}

######################################################################################
#' @title Clusters occurrences or eents
#' @description cluster_method is either "Sequential similarity" or "Contextual Similarity" or "Network Structure"
#' @name clusterEvents
#' @param  e  a dataframe of events or occurrences
#' @param NewMapName = used to store this mapping for visualization and comparison
#' @param cluster_method = method for clustering
#' @param thread_CF - context factors used to delineate threads
#' @param event_CF - context factors used to define events
#' @param what_to_return POV or Cluster solution
#' @return event data frame with occurrences aggregated into events or cluster solution
#' @export
clusterEvents <- function(e, NewMapName, cluster_method, thread_CF, event_CF,what_to_return='POV'){


  if (cluster_method=="Sequential similarity")
  { dd = dist_matrix_seq(e) }
  else if (cluster_method=="Contextual Similarity")
  { dd = dist_matrix_context(e,event_CF) }
  else if (cluster_method=="Network Proximity")
  {
    # The focal column is used to trade the network.  It will probably only be present in the OneToOne mapping, but we should check more generally
    # if it's not present, then use the highest granularity of zooming available.
    focalCol =newColName(event_CF)
    # print(paste('in cluster_events, at first, focalCol=',focalCol))
    # print( colnames(e))

    if (! focalCol %in% colnames(e))
    {focalCol = paste0('ZM_',zoom_upper_limit(e))}
    # print(paste('in cluster_events, then, focalCol=',focalCol))
    dd = dist_matrix_network(e,focalCol) }

  # if there are NA or NaN values, replace then with numbers 10x as big as the largest
  dd[is.na(dd)] = max(dd[!is.na(dd)])*10
  dd[is.infinite(dd)] = max(dd[!is.infinite(dd)])*10

  ### cluster the elements
  clust = hclust( dd,  method="ward.D2" )


  ######## need to delete the old ZM_ columns and append the new ones.  ###########
  e[grep("ZM_",colnames(e))]<-NULL

  # number of chunks is the number of rows in the distance matrix
  nChunks = attr(dd,'Size')

  # print(paste('nChunks = ', nChunks))

  # make new data frame with column names for each cluster level
  zm = setNames(data.frame(matrix(ncol = nChunks, nrow = nChunks)), paste0("ZM_", 1:nChunks))

  ## Create a new column for each cluster solution
  for (cluster_level in 1:nChunks){

    clevelName = paste0("ZM_",cluster_level)
    zm[clevelName] = cutree(clust, k=cluster_level)

  } # for cluster_level

  # append this onto the events to allow zooming
  # need to handle differently for network clusters
  # we are relying on "unique" returning values in the same order whenever it is called on the same data
  if (cluster_method=="Network Proximity")
    {merge_col_name = newColName(event_CF)
    zm[[merge_col_name]]=unique(e[[merge_col_name]])
    newmap = merge(e, zm, by=merge_col_name)
  }
  else
  {newmap=cbind(e, zm)}

  # save(newmap,e,zm, file='O_and_E_zoom.rdata')


  ##### return the cluster solution for display if so desired. Otherwise, just return the new POV map
  if (what_to_return=='cluster')
  {return(list(cluster_result=clust, POV=newmap))}
  else
   {return(newmap)}
}


# this is used for the regex pages to show the threads.
# similar code is used in count_ngrams and to make networks, but with different delimiters
# and with a minimum sequence length (ngram size), but this can be filtered after this function3
#' @title thread_text_vector
#' @description Create a vector of threads
#' @name thread_text_vector
#' @param  o  a dataframe of events or occurrences
#' @param TN = threadNum
#' @param CF = CF or columm to include
#' @param delimiter usually comma or blank
#' @return vector of threads as delimited character strings
#' @export
 thread_text_vector <- function(o, TN, CF, delimiter){

  # Initialize text vector
  tv = vector(mode="character")

  # Loop through the unique thread numbers
  j=0
  for (i in unique(o[[TN]])){
    txt =o[o[[TN]]==i,CF]

    j=j+1
    tv[j] = str_replace_all(concatenate(o[o[[TN]]==i,CF] ),' ',delimiter)
  }
  return(tv)

}

#############################################################################
#############################################################################
##  LOCAL FUNCTIONS from here on down
#############################################################################
#############################################################################

# this function pulls computes their similarity of chunks based on sequence
# these functions are only used locally
dist_matrix_seq <- function(e){

  nChunks = nrow(e)
  evector=vector(mode="list", length = nChunks)
  for (i in 1:nChunks){
    evector[i]=unique(as.integer(unlist(e$occurrences[[i]])))
  }
  return( stringdistmatrix( evector, method="osa") )
}

# this function pulls computes their similarity of chunks based on context
# e = events, with V_columns
# CF = event CFs
# w = weights (0-1)
#
dist_matrix_context <- function( e, CF ){

  nChunks = nrow(e)
  evector= VCF_matrix( e, paste0( "V_",CF ))

  return( dist( evector, method="euclidean") )
}

# this function computes their similarity of chunks based on network
dist_matrix_network <- function(e,CF){

  # first get the nodes and edges
  n=threads_to_network_original(e,'threadNum',CF)

   # print(paste('in dist_matrix_network, n=', n))
   # print(n$nodeDF[['label']])
   # print(n$edgeDF)


  # now get the shortest paths between all nodes in the graph
  d=distances(graph_from_data_frame(n$edgeDF),
              v=n$nodeDF[['label']],
              to=n$nodeDF[['label']])

  return( as.dist(d) )
}


net_adj_matrix <- function(edges){

  return(as_adj(graph_from_edgelist(as.matrix(edges))))

}

# new data structure for events (BTP 3/28)
make_event_df <- function(event_CF,compare_CF,N){

  # Make a data frame with columns for each CF, and put one vector into each column
  e = data.frame(
    tStamp = character(N),  # this is the event start time
    relativeTime = character(N),
    eventDuration = numeric(N),
    label = character(N),
    occurrences = integer(N),
    threadNum = integer(N),
    seqNum = integer(N))

  # set as.POSIXct
    e$tStamp=as.POSIXct("2010-12-07 08:00:00")
    e$relativeTime=as.POSIXct("2010-12-07 08:00:00")

  # print(paste("in make_event_df, event_CF=",event_CF))
  # print(paste("in make_event_df, compare_CF=",compare_CF))

  # add columns for each of the context factors used to define events
  # first make the dataframes for each
  cf1v=setNames(data.frame(matrix(ncol = length(event_CF), nrow = N)), paste0("V_",event_CF))
  cf2=setNames(data.frame(matrix(ncol = length(compare_CF), nrow = N)), compare_CF)

  # Then combine them
  e = cbind(e, cf2,cf1v)

  # and add one more column for the event code/description -- maybe use label instead of this?
  e$ZM_1 = character(N)

  return(e)
}

# this will convert the context factor into a list (like this: 0 0 0 0 0 0 0 0 1 0 0)
# o is the dataframe of occurrences
# CF is the context factor (column)
# r is the row (occurrence number in the One-to-One mapping)
convert_CF_to_vector <- function(o,CF,r){

  return(as.integer((levels(o[[CF]]) ==o[[r,CF]])*1))

}


# Aggregate the VCF (CF vector) for that CF
# There are two layers to this.
# 1) aggregate_VCF_for_event
#   Within an single event, aggregate the VCF for the occurrences that make up that event.
#   This function will only get used when creating from the fuctions that convert occurrences to events
# 2) aggregate_VCF_for_cluster
#   For a cluster level, aggregate the events at that cluster level (e.g., ZM_n)
#   This function will work on any event, even the one_to_one mapping.
#
# o is a dataframe of occurrences.  The values of V_ (the VCF) does not have to be filled in.  It gets re-computed here for each occurrence.
# occlist is the list of occurrences of that event (e$occurrences)
# cf is the name of the contextual factor to create the VCF
aggregate_VCF_for_event <- function(o, occList, cf){

  # get the column name for the VCF
  VCF = paste0("V_",cf)

  # start with the first one so the dimension of the vector is correct
  aggCF = convert_CF_to_vector(o, cf, unlist(occList)[1])

   # print( aggCF)

  # now add the rest, if there are any
  if (length(unlist(occList)) > 1){
    for (idx in seq(2,length(unlist(occList)),1)){
      aggCF = aggCF + convert_CF_to_vector(o, cf, unlist(occList)[idx])
    }}
  return(aggCF)
}


# this version  assumes that the VCF is already computed.
# Might come in handy, but it's not correct...
aggregate_VCF_for_regex <- function(o, occList, cf){

  # get the column name for the VCF
  VCF = paste0("V_",cf)

  # start with the first one so the dimension of the vector is correct
  aggCF = unlist(o[unlist(occList)[1],VCF])

  # print( aggCF)

  # now add the rest, if there are any
  if (length(unlist(occList)) > 1){
    for (idx in seq(2,length(unlist(occList)),1)){
      # print( aggCF)
      aggCF = aggCF+unlist(o[[unlist(occList)[idx],VCF]])
    }}
  return(aggCF)
}



# Same basic idea, but works on a set of events within a cluster, rather than a set of occurrences within an event
# so you get get a subset of rows, convert to a matrix and add them up
# e holds the events
# cf holds a single contextual factor, so you need to call this in a loop
# zoom_col and z are used to subset the data.  They could actually be anything.
aggregate_VCF_for_cluster <- function(e, cf, eclust, zoom_col){

  # get the column name for the VCF
  VCF = paste0("V_",cf)

  # get the matrix for each

  # get the subset of events for that cluster  -- just the VCF column
  # s =  e[ which(e[[zoom_col]]==eclust), VCF]   This version uses the
  s =  e[ which(as.integer(e[[zoom_col]])==eclust), VCF]

  # print (s)
  # print(paste("length(s)",length(s)))
  if ( is.null(unlist(s) ))
    return(NULL)
  else
    return( colSums( matrix( unlist(s), nrow = length(s), byrow = TRUE) ))
}


# this one takes the whole list
VCF_matrix <- function(e, vcf ){

  m = one_vcf_matrix(e, vcf[1] )

  if (length(vcf)>1){
    for (idx in seq(2,length(vcf),1)){
      m = cbind( m, one_vcf_matrix(e, vcf[idx] ) )
    }}
  return(m)
}

# this one takes a single column as an argument
one_vcf_matrix <- function(e, vcf){
  return(  matrix( unlist( e[[vcf]] ), nrow = length( e[[vcf]] ), byrow = TRUE)  )
}




# use this to replace patterns for regex and ngrams
# tv is the text vector for the set of threads
# rx is the dataframe for regexpressions ($pattern, $label)
replace_regex_list <- function(tv, rx ){

  for (i in 1:length(tv)) {
    for (j in 1:nrow(rx) ) {
      tv[i] = str_replace_all(tv[i],rx$pattern[j],rx$label[j])
    }
  }
  return(tv)
}
# same function, but with lapply -- but does not work.
# replace_regex_list_lapply <- function(tv, rx){
#
#   lapply(1:length(tv), function(i){
#     lapply(1:nrow(rx),function(j){
#       str_replace_all(tv[i], rx$pattern[j], rx$label[j] )  }
#     )  })
# }

# No longer needed?
# selectize_frequent_ngrams<- function(e, TN, CF, minN, maxN, threshold){
#
#   f=str_replace_all(trimws(frequent_ngrams(e, TN, CF, minN, maxN, threshold,TRUE)[,'ngrams'], which=c('right')), ' ',',')
#   return(f)
# }


# combined set of frequent ngrams
# add parameter to make maximal a choice
#' @title frequent_ngrams
#' @description combined set of frequent ngrams within a range o lengths
#' @name frequent_ngrams
#' @param  e  event data
#' @param TN threadNum
#' @param CF context factor (column) to look at
#' @param minN  miniumum ngram length
#' @param maxN  maximum ngram length
#' @param onlyMaximal Filters out ngrams that are included in longer ngrams.  Default is true.
#' @return dataframe of ngrams
#' @export
frequent_ngrams <- function(e, TN, CF, minN, maxN, onlyMaximal=TRUE){

  # initialize the output
  ng = count_ngrams(e,TN, CF,minN)

  if (maxN > minN){
    for (i in seq(minN+1,maxN,1)){
      ng = rbind(ng,count_ngrams(e,TN, CF,i)) }
  }
  # remove the rows that happen once and only keep the columns we want
  ng=ng[ng$freq>1,c('ngrams','freq', 'len')]

  # just take the maximal ones if so desired
  if (onlyMaximal) { ng=maximal_ngrams(ng)  }

  # return the set sorted by most frequent
  return(ng[order(-ng$freq),])
}

# this filters out ngrams that are contained within others ('2 2' is part of '2 2 2')

maximal_ngrams <- function(ng){

  # find out if each ngram is contained in all the others
  w = lapply(1:nrow(ng), function(i){
    grep(ng$ngrams[i],ng$ngrams)}
  )

  # get howMany times each one appears
  howMany = lapply(1:length(w), function(i){
    length(w[[i]])}
  )

  # return the ones that are unique
  return(ng[which(howMany==1),])
}

# compute support level for each ngram
# tv = text vectors for the threads
# ng = frequent ngrams data frame
# returns ng data frame with support level added
#' @title support_level
#' @description Counts what fraction of the threads a particular ngram appears in
#' @name support_level
#' @param  tv  text vector of threads
#' @param ng ngram to be located in the threads
#' @return percentage of threads containing the ngram
#' @export
support_level <- function(tv, ng) {

  # change the commas back to spaces
  tv=str_replace_all(tv, ',' , ' ')

  totalN = length(tv)

  # need to remove whitespace from the trailing edge of the ngrams
  ng$ngrams = trimws(ng$ngrams)

  # find out how many times each ngram is contained in each TV
  ng$support = unlist(lapply(1:nrow(ng), function(i){
    length(grep(ng$ngrams[i],tv)) })
  )/totalN

  # toss in the generativity level
  ng = generativity_level(tv,ng)

  return(ng)
}


generativity_level<- function(tv, ng){

  # for each ngram, look at the next longer size
  # Find the n+1-grams that match (as in the code for maximal ngrams).
  # There are two possibilities -- matching in the first or second position
  # The number of matches in the first position =  the out-degree
  # The number of matches in the second position =  the in-degree
  # if so desired, it should be possible to keep a list.

  # problem is that the tokens can be 1-3 characters long, and there are spaces...

  # Big Idea for frequent n-grams: use the DT:: and let people sort, select and apply all the ngrams they want.
  # Name them using the tokens but with a different delimiter to avoid confusion.  Go Crazy!

  # convert to spaces
  tv=str_replace_all(tv, ',',' ')

  # first get the range we are looking for
  nList = unique(ng$len)

  z=list()

  # loop through them
  for (n in nList){

    # print(paste('n = ',n))
    #pick the ngrams of length n from the list given
    ngn= ng[ng$len==n,]


    # get ngrams of length n+1 -- make sure the threads are long enough
    ngplus = get.phrasetable(ngram( long_enough(tv,n+1, ' '), n+1))

    # this picks out the ones that match
    w = lapply(1:nrow(ngn), function(i){
      grep(ngn$ngrams[i],ngplus$ngrams)} )

    #print(w)
    # print('z = ')
    zplus = lapply(1:nrow(ngn), function(i){
      str_locate(ngplus$ngrams[w[[i]]],ngn$ngrams[i])  } )

    # print(z)

    z = c(z,zplus)

  }

  # compute the in and out degree
  ng$in_degree = unlist(lapply(1:nrow(ng), function(i){
    zm=z[[i]]
    length( zm[zm[,1]>1,1] )  } ))

  ng$out_degree = unlist( lapply(1:nrow(ng), function(i){
    zm=z[[i]]
    length( zm[zm[,1]==1,1] )  } ))

  # ng$generativity = lapply(1:nrow(ng), function(i) {ng$out_degree[i] * ng$in_degree[i]})

  return(ng)
}

# to avoid errors in count_ngrams, make sure the length of each thread in the text_vector tv is longer than the n-gram size, n
# this gets used in various places so need to pass in the delimiter
long_enough = function(tv,n,delimiter){

  return(tv[ unlist(lapply(1:length(tv), function(i) {length(unlist(strsplit(tv[[i]],delimiter)))>=n})) ])

}

# cluster by network path length
