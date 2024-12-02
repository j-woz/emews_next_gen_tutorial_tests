#!/bin/bash 

# INSTALL EMEWS SH
# See README.adoc

# Are we running under an automated testing environment?
if (( ${#JENKINS_URL} > 0 ))
then
    echo "detected auto test Jenkins"
    AUTO_TEST="Jenkins"
elif (( ${#GITHUB_ACTION} > 0))
then
    echo "detected auto test GitHub"
    AUTO_TEST="GitHub"
else
    # Other- possibly interactive user run.  Set to empty string.
    AUTO_TEST=""
fi

function start_step {
    if (( ${#AUTO_TEST} ))
    then
        # Normal shell run
        echo -en "[ ] $1 "
    else
        # Auto test run
        echo -e  "[ ] $1 "
    fi
}

function end_step {
    if (( ${#AUTO_TEST} ))
    then
      # Normal shell run - overwrite last line and show check mark
      echo -e "\r[\xE2\x9C\x94] $1 "
    else
      # Auto test run
      echo -e "[X] $1 "
    fi
}

function on_error {
    msg="$1"
    # Log may be blank if the step does not use a log
    log="$2"

    echo -e "\n\nError: $msg"

    if [[ ${AUTO_TEST} != "GitHub" ]]
    then
        # Non-GitHub run - user can retrieve log
        echo "See $log for details"
    else
        # GitHub run - must show log now
        if (( ${#log} > 0 ))
        then
            echo "showing log: $log"
            cat $log
        fi
    fi
    exit 1
}

VALID_VERSIONS=("3.8" "3.9" "3.10" "3.11")
V_PREFIX=(${VALID_VERSIONS[@]::${#VALID_VERSIONS[@]}-1})
V_SUFFIX="${VALID_VERSIONS[@]: -1}"
printf -v joined '%s, ' "${V_PREFIX[@]}"
V_STRING="${joined% } or $V_SUFFIX"

help() {
   echo "Usage: install_emews.sh <python-version> <database-directory>"
   echo "       install_emews.sh -h"
   echo
   echo "Arguments:"
   echo "  python-version         python version to use ($V_STRING)"
   echo "  database-directory     EQ/SQL Database installation directory" 
   echo "  h                      display this help and exit"
   echo
   echo "Example:"
   echo "  install_emews.sh 3.11 ~/Documents/db/eqsql_db"
}

while getopts ":h" option; do
   case $option in
      h) # display Help
         help
         exit;;
      \?) # incorrect option
         help
         exit;;
   esac
done

if [ "$#" -ne 2 ]; then
    help
    exit
fi

PY_VERSION=''
for V in "${VALID_VERSIONS[@]}"; do
    if [ $V = $1 ]; then
        PY_VERSION=$V
    fi
done

if [ -z "$PY_VERSION" ]; then
    echo "Error: python version must be one of $V_STRING."
    exit
fi

if [ -d $2 ]; then
    echo "Error: Database directory already exists: $2"
    echo "       This script will not overwrite an existing database."
    echo "       Remove it or specify a different directory."
    exit 1
fi


if [ ! $(command -v conda) ]; then
    echo "Error: conda executable not found. Conda must be activated."
    echo "Try \"source ~/anaconda3/bin/activate\""
    exit 1
fi

CONDA_BIN=$(which conda)
if [[ ${AUTO_TEST} != "GitHub" ]]
then
    CONDA_BIN_DIR=$(dirname $CONDA_BIN)
else
    # The installation is a bit different on GitHub
    # conda    is in $CONDA_HOME/condabin
    # activate is in $CONDA_HOME/bin
    CONDA_HOME=$(dirname $CONDA_BIN_DIR)
    CONDA_BIN_DIR=$CONDA_HOME/bin
fi

THIS=$( cd $( dirname $0 ) ; /bin/pwd )
EMEWS_INSTALL_LOG="$THIS/emews_install.log"

echo "Starting EMEWS stack installation"
echo "See ${THIS}/emews_install.log for detailed output."
echo

echo "Using conda bin: $CONDA_BIN_DIR"

ENV_NAME=emews-py${PY_VERSION}
TEXT="Creating conda environment '${ENV_NAME}' using Python ${PY_VERSION}"
start_step "$TEXT"
# echo "Creating conda environment '${ENV_NAME}' using ${PY_VERSION}"
conda create -y -n $ENV_NAME python=${PY_VERSION} > "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

TEXT="Activating conda environment"
start_step "$TEXT"
echo "activating: $CONDA_BIN_DIR/activate '$ENV_NAME'"
ls -l $CONDA_BIN_DIR/activate
source $CONDA_BIN_DIR/activate $ENV_NAME || on_error "$TEXT"
echo "python:  " $(which python)
echo "version: " $(python -V)
echo "conda:   " $(which conda)
end_step "$TEXT"

# !! conda activate $ENV_NAME doesn't work within the script
TEXT="Installing swift-t conda package"
start_step "$TEXT"
conda install -y -c conda-forge -c swift-t swift-t-r >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
conda deactivate
source $CONDA_BIN_DIR/activate $ENV_NAME
end_step "$TEXT"

TEXT="Installing EMEWS Queues for R"
start_step "$TEXT"
conda install -y -c conda-forge -c swift-t eq-r >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

TEXT="Upgrading conda gcc"
# Upgrades from 11.2.0 to 12.3.0 on GCE Jenkins (Ubuntu 20) (2024-06-11)
start_step "$TEXT"
conda upgrade -y -c conda-forge gcc >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

TEXT="Installing PostgreSQL"
start_step "$TEXT"
conda install -y -c conda-forge postgresql==14.12 >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

TEXT="Installing EMEWS Creator"
start_step "$TEXT"
pip install emewscreator >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

TEXT="Initializing EMEWS Database"
emewscreator init_db -d $2 >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

THIS=$( cd $( dirname $0 ) ; /bin/pwd )

echo
echo "Using Rscript: $(which Rscript)"

TEXT="Initializing Required R Packages"
start_step "$TEXT"
Rscript $THIS/install_pkgs.R >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
Rscript -e "remotes::install_github('emews/EQ-SQL/R/EQ.SQL')" >> "$EMEWS_INSTALL_LOG" 2>&1 || on_error "$TEXT" "$EMEWS_INSTALL_LOG"
end_step "$TEXT"

echo
echo "# To activate this EMEWS environment, use"
echo "#"
echo "#     $ conda activate $ENV_NAME"
echo "#"
echo "# To deactivate an active environment, use"
echo "#"
echo "#     $ conda deactivate"

# Local Variables:
# sh-basic-offset: 4
# End:
