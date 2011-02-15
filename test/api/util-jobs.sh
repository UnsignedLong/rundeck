#!/bin/bash

#Usage: 
#    util-jobs.sh <project> [URL] [param=value [param=value] .. ]

errorMsg() {
   echo "$*" 1>&2
}

DIR=$(cd `dirname $0` && pwd)

proj=$1
if [ "" == "$1" ] ; then
    proj="test"
fi
shift
# accept url argument on commandline, if '-' use default
url="$1"
if [ "-" == "$1" ] ; then
    url='http://localhost:4440'
fi
shift
apiurl="${url}/api"
VERSHEADER="X-RUNDECK-API-VERSION: 1.2"

# curl opts to use a cookie jar, and follow redirects, showing only errors
CURLOPTS="-s -S -L -c $DIR/cookies -b $DIR/cookies"
CURL="curl $CURLOPTS"

if [ ! -f $DIR/cookies ] ; then 
    # call rundecklogin.sh
    sh $DIR/rundecklogin.sh $url
fi

XMLSTARLET=xml

# now submit req
runurl="${apiurl}/jobs"

echo "# Listing RunDeck Jobs for project ${proj}..."

params="project=${proj}"


# get listing
$CURL --header "$VERSHEADER" ${runurl}?${params} > $DIR/curl.out
if [ 0 != $? ] ; then
    errorMsg "ERROR: failed query request"
    exit 2
fi

#test curl.out for valid xml
$XMLSTARLET val -w $DIR/curl.out > /dev/null 2>&1
if [ 0 != $? ] ; then
    errorMsg "ERROR: Response was not valid xml"
    exit 2
fi

#test for expected /joblist element
$XMLSTARLET el $DIR/curl.out | grep -e '^result' -q
if [ 0 != $? ] ; then
    errorMsg "ERROR: Response did not contain expected result"
    exit 2
fi

# job list query doesn't wrap result in common result wrapper
#If <result error="true"> then an error occured.
waserror=$($XMLSTARLET sel -T -t -v "/result/@error" $DIR/curl.out)
if [ "true" == "$waserror" ] ; then
    errorMsg "Server reported an error: "
    $XMLSTARLET sel -T -t -v "/result/error/message" -n  $DIR/curl.out
    exit 2
fi

#Check projects list
itemcount=$($XMLSTARLET sel -T -t -v "/result/jobs/@count" $DIR/curl.out)
#echo "$itemcount Jobs"    
if [ "0" != "$itemcount" ] ; then
    #echo all on one line
    $XMLSTARLET sel -T -t -m "/result/jobs/job" -v "@id" -o " " -v "name" -o " (" -v "group" -o ") " -o ": &quot;" -v "description" -o '&quot;'  -n $DIR/curl.out
fi

rm $DIR/curl.out
