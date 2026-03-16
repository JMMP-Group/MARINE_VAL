#!/bin/bash


##### You want to set RUNEXP and which .sh to run

# ---- set-up ---- 
RUNEXP="EXP_RUN"


# ---- linking definitions ----
SYMLINKS=()   # array to track created links
for f in EXP/${RUNEXP}/*; do
  echo "Linking ${f}"
  link="$(basename "$f")"
  ln -s "$f" "$link"
  SYMLINKS+=("$link")
done

# ---- running ----
sh "run_monitoring.sh"  


# ---- cleanup ----
for link in "${SYMLINKS[@]}"; do
  echo "Removing ${link}"
  rm "$link"
done


