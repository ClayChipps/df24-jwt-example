#!/bin/bash

###############################################################
# 
# resetScratchOrg [-a <scratch_org_alias>] [--alias <scratch_org_alias>]
#                 [-d <duration in days>]  [--duration <duration in days>]
#                 [-c] [--clean]
#                 [-h] [--help] 
# 
###############################################################

usage () {
  echo 'Usage: resetScratchOrg [-a <scratch_org_alias>] [--alias <scratch_org_alias>]'
  echo '                       [-d <duration in days>] [--duration <duration in days>] '
  echo '                       [-c] [--clean] '
  echo '                       [-h] [--help]'
  exit 0
}

exit_if_next_arg_is_invalid () {
  [[ -z "$1" ]] && usage
  [[ "$1" =~ ^\- ]] && usage
}

clean_run=false
definition_file='config/project-scratch-def.json'
duration='30'
org_alias=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    '-a'|'--alias')
      shift
      exit_if_next_arg_is_invalid "$1"
      org_alias="$1"
      shift
      ;;
    '-d'|'--duration')
      shift
      exit_if_next_arg_is_invalid "$1"
      duration="$1"
      shift
      ;;
    '-c'|'--clean')
      shift
      clean_run=true
      shift
      ;;
    '-h'|'--help')
      usage
      ;;
    *)
      usage
      ;;
  esac
done

# Get the logs directory
logs=logs

# Is this a clean run?
if [[ -d "${logs}" && "${clean_run}" = true ]]
  then
    rm -r "${logs}"
fi 

# Does the logs directory exist?
if [ ! -d "${logs}" ]
  then
    mkdir "${logs}"
fi 

chmod -R 0644 "${logs}"

# Add log file for the current run
current_time=$(date "+%Y%m%d.%H%M")
log_file=logs/scratch-org-setup-$current_time.log
progress_file=scratch-org-setup-progress-"${org_alias}"

# Clean up remote git branches
git remote prune origin 2> /dev/null

if [ -z "${org_alias}" ]
  then
    echo "Please provide the username / org alias."
    exit 1
fi

echo "org_alias is ${org_alias}"
echo "definition_file is ${definition_file}"
echo "duration is ${duration}"

# Does the progress file exist?
if [ ! -f "${logs}/${progress_file}" ]
  then
    if [ "$(sf org list --json | grep -c "${org_alias}")" -ne 0 ]
      then
        echo 0 > "${logs}/${progress_file}"
      else
        echo 1 > "${logs}/${progress_file}"
    fi
fi 

progress_marker_value=$(<"${logs}/${progress_file}")

# Delete any previous scratch org with same alias
if [ 1 -gt "${progress_marker_value}" ]
  then
    echo "Marking ${org_alias} for deletion"
    sf org delete scratch --target-org "${org_alias}" --no-prompt --json | tee -a "${log_file}"
    echo 1 > "${logs}/${progress_file}"
    progress_marker_value=1
fi

set -e
set -o pipefail

# Create new scratch org
if [ 2 -gt "${progress_marker_value}" ]
  then
    echo "Creating new scratch org aliased: ${org_alias}"
    sf org create scratch --duration-days "${duration}" --definition-file "${definition_file}" --alias "${org_alias}" --wait 30 --json | tee -a "${log_file}"
    echo 2 > "${logs}/${progress_file}"
    progress_marker_value=2
fi

# Set scratch org and scratch default user to EST timezone. Also purge sample data.
if [ 3 -gt "${progress_marker_value}" ]
  then
    echo "Preparing scratch org"
    ./bin/prepareScratchOrg.sh --target-org "${org_alias}" | tee -a "${log_file}"
    echo 3 > "${logs}/${progress_file}"
    progress_marker_value=3
fi

# Push source code to org.
if [ 5 -gt "${progress_marker_value}" ]
  then
    echo "Pushing to ${org_alias}"
    sf project deploy start --target-org "${org_alias}" --ignore-conflicts --json | tee -a "${log_file}"
    echo 5 > "${logs}/${progress_file}"
    progress_marker_value=5
fi

# Finalize the scratch org for use
if [ 6 -gt "${progress_marker_value}" ]
  then
    echo "Finalizing scratch org"
    ./bin/finalizeScratchOrg.sh --target-org "${org_alias}" | tee -a "${log_file}"
    echo 6 > "${logs}/${progress_file}"
    progress_marker_value=6
fi

# Remove marker file
rm "${logs}/${progress_file}"

echo "${org_alias} setup complete"