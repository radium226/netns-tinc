#!/bin/bash

error()
{
  echo -e "[ERROR] ${COLOR_RED}${@}${COLOR_DEFAULT}" >&2
}

info()
{
  echo -e "[INFO]  ${COLOR_BLUE}${@}${COLOR_DEFAULT}" >&2
}

debug()
{
  echo -e "[DEBUG] ${@}" >&2
}

die()
{
  error "${@}"
  exit ${FAILURE}
}
