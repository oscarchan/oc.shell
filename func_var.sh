#! /bin/bash
#
#  test how variables are used
#

FUNC_VAR=before
func_var() {
  echo variable = $FUNC_VAR 
}

func_var
