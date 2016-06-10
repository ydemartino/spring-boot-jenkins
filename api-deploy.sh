#!/bin/bash

# COMMAND LINE VARIABLES
#enviroment FIRST ARGUMENT 
# Ex: dev | sit | uat
env=$1
# SECOND ARGUMENT project name, deploy folder name and jar name
projectName=$2 #spring-boot

#### CONFIGURABLE VARIABLES ######
#destination absolute path. 
destAbsPath=/var/lib/jenkins/spring-boot/$projectName/$env
##############################################################

#####
##### DONT CHANGE HERE ##############
#jar file
# $WORKSPACE is a jenkins var
sourFile=$WORKSPACE/build/libs/$projectName*.jar
destFile=$destAbsPath/$projectName.jar

#CONSTANTS
logFile=initServer.log
pidFile=application.pid
dstLogFile=$destAbsPath/$logFile
dstPidFile=$destAbsPath/$pidFile
#whatToFind="Started Application in"
whatToFind="Started "
msgLogFileCreated="$logFile created"
msgAppStarted="Application Started... exiting buffer!"

### FUNCTIONS
##############
function stopServer(){
    echo " "
    echo "Stoping process"

    if [ ! -f $dstPidFile ] || ! kill -0 `cat $destAbsPath/$pidFile`; then
        return 1
    fi

    PID=`cat $destAbsPath/$pidFile`

    kill -INT $PID

    echo "Waiting for process to terminate..."

    COUNTER=15
    until [ $COUNTER -lt 0 ]; do
        sleep 1
        if ! kill -0 $PID >& /dev/null; then
            break
        fi
        let COUNTER-=1
    done

    if kill -0 $PID >& /dev/null; then
        echo "Process not terminated, force kill..."
        kill $PID
    else
        echo "Process terminated gracefully"
    fi

    echo " "
}

function deleteFiles(){
    echo "Deleting $destFile"
    rm -rf $destFile

    echo "Deleting $dstLogFile"
    rm -rf $dstLogFile

    echo " "
}

function copyFiles(){
    if [ ! -d $destAbsPath ]; then
        echo "Creating $destAbsPath"
        mkdir -p $destAbsPath
    fi

    echo "Copying files from $sourFile"
    cp $sourFile $destFile

    echo " "
}

function run(){

   cd $destAbsPath

   nohup nice java -jar $destFile 1> $dstLogFile 2>&1 &

   cd -

   echo "COMMAND: nohup nice java -jar $destFile $> $dstLogFile 2>&1 &"

   echo " "
}

function changeFilePermission(){

    echo "Changing File Permission: chmod 777 $destFile"

    chmod 777 $destFile

    echo " "
}

function watch(){

    tail -f $dstLogFile |

        while IFS= read line
            do
                echo "$line"

                if [[ "$line" == *"$whatToFind"* ]]; then
                    echo $msgAppStarted
                    pkill  tail
                fi
        done
}

### FUNCTIONS CALLS
#####################
# Use Example of this file. Args: enviroment | project name
# BUILD_ID=dontKillMe /path/to/this/file/api-deploy.sh dev spring-boot

# 1 - stop server with PID ...
stopServer

# 2 - delete destinations folder content
deleteFiles

# 3 - copy files to deploy dir
copyFiles

changeFilePermission
# 4 - start server
run

# 5 - watch loading messages until  ($whatToFind) message is found
watch

