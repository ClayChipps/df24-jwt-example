#!/bin/bash

###############################################################
# 
# finalizeScratchOrg [-u <target_org>] [--target-org <target_org>]
#                    [-h] [--help] 
# 
###############################################################

usage () {
  echo 'Usage: finalizeScratchOrg [-u <target_org>] [--target-org <target_org>]'
  echo '                          [-h] [--help]'
  exit 0
}

exit_if_next_arg_is_invalid () {
  [[ -z "$1" ]] && usage
  [[ "$1" =~ ^\- ]] && usage
}

target_org=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    '-u'|'--target-org')
      shift
      exit_if_next_arg_is_invalid "$1"
      target_org="$1"
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

set -e
