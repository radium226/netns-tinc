#!/bin/bash

check()
{
  declare label="${1}"; shift
  echo     " --> ${label}: "

  declare alter_command="${1}" ; shift

  declare alter=
  for alter in true false; do
    echo -en "      - ["
    set +e
    declare output
    output="$( $( if ${alter}; then echo ${alter_command}; fi ) "${@}" 2>&1 )"
    declare exit_code="${?}"
    set -e

    if [[ ${exit_code} -eq 0 ]]; then
      echo -en "${COLOR_GREEN}${SYMBOL_OK}${COLOR_DEFAULT}"
    else
      echo -en "${COLOR_RED}${SYMBOL_KO}${COLOR_DEFAULT}"
    fi
    echo "] $( ${alter} && echo "Altered" || echo "Not Altered" )"

    if [[ ${exit_code} -ne 0 || ${PRINT_ANYWAY:-0} -eq 1 ]]; then
      echo -e "${COLOR_GREY}${output}${COLOR_DEFAULT}"
    fi
  done
}
