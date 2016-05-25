# spring-boot-jenkins
Example of the deployment of a Spring Boot App with Jenkins in a Unix System

One thing that I found very hard to do was to integrate a spring boot project into a CI environment using jenkins. As a default behavior, the Jenkins process tree killer always kills the process started by a job which stops the execution of a Spring Boot App after the jenkins job finishes. In addition of that, I wanted to see the server log on the jenkyns windows until it finishes loading. This article will try to help us solving this problems.

But first I would like to discuss what I consider a good practice to a Spring Boot App CI environment. I find very useful to first copy the artifacts to a specified area on the server to keep track of the artifacts deployed and deploy the artifact from that location. Also, I create a server log  file there and start to listening on the jenkins window until the server started.

So the script below does that. With some minor improvements self explained on the comments, but in summary it does this:

- stop former process using PID
- delete the files of the previous deploy 
- copy the files to deploy location 
- start application with nohup command, java - jar
- start listening to the server log until it reaches an specific instruction.


Finally you have to do some adjustments to your job on Jenkins to avoid the default tree killing process. Just add this instruction before calling the sh: BUILD_ID=dontKillMe /path/to/my/script.sh (FIGURE 3) 

You can see the jenkins job configuration window on FIGURES 1, 2, and 3 and the log result window on FIGURES 4 and 5.

Go to my github repo to check the project, but it recommend to extract the shell script to another repo to keep it lifecycle independent of your app.

https://github.com/rcoli/spring-boot-jenkins
  

This is my deploy folder structure (FIGURE 6):
```
-- spring-boot

---- dev
------ application.pid
------ initServer.log
------ my-app-jar

---- sit
------ application.pid
------ initServer.log
------ my-app-jar

---- uat
------ application.pid
------ initServer.log
------ my-app-jar
```
* dev - develop, sit - system integration testing, uat - user acceptance testing, application.yml - external app configuration file


This my project folder structure (FIGURE 7 and 8):
```
-- my-project
---- resources
------ application.yml
---- api
------ src
------ (other project file)
------ build.gradle
```

The script example.

```bash

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
        kill -0 $PID >& /dev/null
        if [ $? ]; then
            break
        fi
        let COUNTER-=1
    done

    kill -0 $PID >& /dev/null

    if [ ! $? ]; then
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

   nohup nice java -jar $destFile $> $dstLogFile 2>&1 &

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

```

--- Jenkins Job Configuration (Git) FIGURE 1
![alt tag](https://cloud.githubusercontent.com/assets/1146514/10940518/ed6d4062-82ed-11e5-88e8-6529970d2831.png)

--- Jenkins Job Configuration (Gradle) FIGURE 2
![alt tag](https://cloud.githubusercontent.com/assets/1146514/10940527/fc1a0078-82ed-11e5-9dd7-aa75924b1d3f.png)

--- Jenkins Job Configuration (Deploy) FIGURE 3
![alt tag](https://cloud.githubusercontent.com/assets/1146514/10940534/0678e232-82ee-11e5-84dd-6ca751e66903.png)



--- Jenkins Summary Beginning FIGURE 4
![alt tag](https://cloud.githubusercontent.com/assets/1146514/10939540/74ed1058-82e9-11e5-9ca8-fcdfa9138647.png)

--- Jenkins Summary Finnished (Job Complete) FIGURE 5
![alt tag](https://cloud.githubusercontent.com/assets/1146514/10939547/7a37dc6e-82e9-11e5-9b1e-bda47592ed6d.png)


--- Deploy Structure Folder FIGURE 6
![alt tag](https://cloud.githubusercontent.com/assets/1146514/10939616/0aefad86-82ea-11e5-8d6b-40ca67df04f2.png)


--- Project structure folder FIGURE 7
![alt tag](https://cloud.githubusercontent.com/assets/1146514/10939537/708ed014-82e9-11e5-85e1-c53ac1d219eb.png)

--- External Resources Folder FIGURE 8
![alt tag](https://cloud.githubusercontent.com/assets/1146514/10939548/7e91ed90-82e9-11e5-8a61-31e6f6f9c42a.png)
