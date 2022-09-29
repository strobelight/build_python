#!/bin/bash


##########################################################################
#   I N I T
##########################################################################

# exit on errors
set -e 

# some constants
BUILD_DEST=$HOME/opt
PYTHONDIR=cpython
export LOGFILE=$(pwd)/make.out


##########################################################################
#   F U N C T I O N S
##########################################################################


##########################################################################
#   Save stdout and stderr to new file descriptors
##########################################################################
saveStdOutErr() {
    exec 5<&1
    exec 6<&2
}


##########################################################################
#   Restore stdout and stderr from saved file descriptors
##########################################################################
restoreStdOutErr() {
    exec 1>&5
    exec 2>&6
    wait
}


##########################################################################
#   Redirect stdout and stderr to LOGFILE
##########################################################################
redirectToLog() {
    exec > >(tee -a $LOGFILE)
    exec 2>&1
}


##########################################################################
#   Close output to LOGFILE and restore original stdout and stderr
##########################################################################
closeLogfile() {
    exec 1>&-
    exec 2>&-
    restoreStdOutErr
}


##########################################################################
#   Grep for a string (passed as arg 1) in LOGFILE
#
#   Return true if found, false otherwise
#
#   Due to buffering of tee to the LOGFILE, need to close it and reopen it
##########################################################################
stringInLogfile() {
    SH_OPTS=$-
    XERR=$(echo $SH_OPTS|grep e || true);set +e
    closeLogfile
    grep --silent "$1" $LOGFILE
    RC=$?
    [ -n "$XERR" ] && set -e || true
    redirectToLog
    [ "$RC" = "0" ]
}


##########################################################################
#   Output a message making it stand out like a banner
##########################################################################
logit() {
    XTRACE=$(echo $-|grep x || true);set +x
    msg="$*"
    msgLen=${#msg}
    SPACER=`eval "printf \%${msgLen}s "`
    LOGSEP=`printf %30s | tr " " "#"`
    newMsg="$LOGSEP $msg $LOGSEP"
    newMsgBlank="$LOGSEP $SPACER $LOGSEP"
    msgLen=${#newMsg}
    LOGSEP=`eval "printf \%${msgLen}s | tr \" \" \"#\""`
    echo
    echo $LOGSEP
    echo $LOGSEP
    echo "$newMsgBlank"
    echo "$newMsg"
    echo "$newMsgBlank"
    echo $LOGSEP
    echo $LOGSEP
    echo
    [ -n "$XTRACE" ] && set -x || true
}


##########################################################################
#   Clone the python source
#
#   (removes any local clone whether or not already present)
##########################################################################
getPythonSource() {
    logit "${FUNCNAME[0]}"
    rm -rf $PYTHONDIR
    git clone https://github.com/python/$PYTHONDIR.git
}


##########################################################################
#   Determine recent python branch besides main/master
##########################################################################
getRecentBranch() {
    RECENT_BRANCH=$(git for-each-ref --sort=-committerdate refs/remotes | sed '1,/HEAD/d;s:.*origin/::;/[a-zA-Z]/d' | sort -f | tail -1)
    logit "${FUNCNAME[0]} found $RECENT_BRANCH"
}


##########################################################################
#   Determine recent tag within recent python branch
##########################################################################
getRecentTag() {
    RECENT_TAG=$(git show-ref --abbrev=7 --tags -d | grep '{}' | sed 's:refs/tags/::;s:\^{}::;s/^.* v/v/' | grep v${RECENT_BRANCH} | tail -1)
    logit "${FUNCNAME[0]} found $RECENT_TAG"
}


##########################################################################
#   Do a git checkout of recent python tag for building
##########################################################################
checkoutTag() {
    logit "${FUNCNAME[0]}"
    git checkout $RECENT_TAG
}


##########################################################################
#   Run the configure script with preferred options
##########################################################################
runConfigure() {
    logit "${FUNCNAME[0]}"
    sleep 3
    ./configure --with-pydebug --with-lto --with-platlibdir=lib64 --prefix=$BUILD_DEST/python-${RECENT_TAG}
    #./configure --enable-optimizations --enable-shared --with-lto --with-platlibdir=lib64 --prefix=$BUILD_DEST/python-${RECENT_TAG} LDFLAGS=-Wl,-rpath,$BUILD_DEST/python-${RECENT_TAG}/lib
}


##########################################################################
#   Run the make and check if all modules built
#
#   Exits with error if all modules not built
##########################################################################
runMake() {
    logit "${FUNCNAME[0]}"
    sleep 2
    make -j --output-sync=target 

    MODULES_NOT_BUILT_STRING="The necessary bits to build these optional modules were not"
    #MODULES_NOT_BUILT_STRING="The following modules found by detect_modules"

    if stringInLogfile "$MODULES_NOT_BUILT_STRING"; then
        logit "E R R O R"
        echo "Some important modules could not be built due to missing headers or libraries" >&2
        exit 1
    fi
}


##########################################################################
#   Test a grep of the log file
#
#   (Could be removed now that the correct way to grep from the LOGFILE
#   was figured out)
##########################################################################
grepTest() {
    saveStdOutErr
    redirectToLog
    date
    MODULES_NOT_BUILT_STRING="The following modules found by detect_modules"
    if stringInLogfile "${1}$MODULES_NOT_BUILT_STRING"; then
        logit "E R R O R"
        echo "Some important modules could not be built due to missing headers or libraries" >&2
        exit 1
    else
        logit "O K"
        echo "$-"
    fi
}


##########################################################################
#   Run the "make install"
##########################################################################
runInstall() {
    rm -rf $BUILD_DEST/python-${RECENT_TAG}
    logit "${FUNCNAME[0]}"
    sleep 2
    make install
}

#grepTest xxx
#grepTest
#exit

##########################################################################
#   M A I N
##########################################################################
rm -f $LOGFILE

saveStdOutErr
redirectToLog
getPythonSource
pushd $PYTHONDIR >/dev/null 2>&1
getRecentBranch
getRecentTag
checkoutTag
runConfigure
runMake
runInstall
popd >/dev/null 2>&1
rm -rf $PYTHONDIR
logit "$BUILD_DEST/python-${RECENT_TAG}/bin/python3"
