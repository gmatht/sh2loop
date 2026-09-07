declare -A config
config[service]=8080
config[user]=admin
config[host]=localhost
for k in "${!config[@]}"; do echo "${config[$k]}"; done
echo "---"
IFS=$'\'' sorted=($(printf "\\n" "${config[@]}" | sort))
echo "${sorted[@]}"
