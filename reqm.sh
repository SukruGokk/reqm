# Request Manager
# Bash version: 5.2.21(1)-release
# 26/01/2024

# main args
declare -A arguments=(["method"]="GET" ["url"]="None" ["headers"]="Content-Type: text/plain" ["data"]='None' ["output"]="None")

# user defined variables
declare -A variables

while true
do
    echo
    read -p "reqm>" input
    case $input in
        help)
            echo "commands:"
            echo "help         - shows this message"
            echo "args         - list the arguments"
            echo "exit         - exit the program"
            echo "send         - send the request"
            echo "output       - set output file"
            echo "save <name>  - save request"
            echo "load <name>  - load saved request"
            echo "use <key>=<value> structure to set arguments or define variables"
            echo "use variables with \$, ex: data=\$user_data"
            echo "for multiple headers use \",\" ex: headers=Content-Type: text/plain, Authorization: Basic <token>"

            ;;
        exit)
            exit
            ;;
        send)
            string='curl -s -w "%{http_code}" ${arguments[url]} -X ${arguments[method]}'
            if [[ ! "${arguments[data]}" = "None" ]]; then
                string+=" -d '${arguments[data]}'"
            fi
            if [[ ! "${arguments[headers]}" = "None" ]]; then
                IFS=',' read -r -a array <<< "${arguments[headers]}"
                for header in "$array[@]"
                do
                    string+=" -H \"$(echo $header | xargs)\""
                done
            fi 
            
            # send request
            response=$(eval $string)
            
            # seperate status code and response content
            http_code=${response:${#response}-3}
            content=${response:0:${#response}-3}
            output="${arguments[output]}"
            
            if [[ ${#output} -gt 4 ]]; then
                output="$(echo $output | tr -d ' ')"
                echo "$content" > "$output"
            fi

            echo "status code: $http_code"
            echo "response body: $content"
            ;;
        args)
            # print arguments from hash table
            for i in "${!arguments[@]}"
            do
                echo "$i: ${arguments[$i]}"
            done
            ;;
        *)
            # emtpy input
            if [[ ! ${#input} -ge 1 ]]; then
                echo "invalid input"
        
            # if there is an assignment (=)
            elif [[ $input = *"="* ]]; then
                key=$(echo $input | cut -d'=' -f 1)
                value=$(echo $input | cut -d'=' -f 2)

                # set argument to a variable
                if [[ $value = *"$"* ]]; then
                    arguments[$key]=${variables["${value:1}"]}
                # set argument directly to a value
                elif [[ -v "arguments[$key]" ]] ; then
                    arguments[$key]=$value
                else
                    # invalid key or value
                    if [[ ! ${#key} -ge 1 ]] || [[ ! ${#value} -ge 1 ]]; then
                        echo "invalid input"
                    # define variable
                    else
                        variables["$key"]="$value"
                    fi
                fi 
            # print user defined variable
            elif [[ -n ${variables[${input}]} ]]; then
                echo ${variables[${input}]}
            # load from save
            elif [[ ${input} = *"load"* ]]; then
                file=$(echo $input | cut -d' ' -f 2)
                IFS=$'\n' # set the Internal Field Separator to newline
              
                for LINE in $(cat ".presets/$file.preset")
                do
                    key=$(echo $LINE | cut -d'½' -f 1)
                    value=$(echo $LINE | cut -d'½' -f 2)

                    arguments[$key]=$value
                done
               
                echo "values are imported from $file"
            # save request
            elif [[ ${input} = *"save"* ]]; then
                file=$(echo $input | cut -d' ' -f 2)
                
                for i in "${!arguments[@]}"
                do
                    echo "$i½${arguments[$i]}" >> ".presets/$file.preset"
                done
                
               echo "variables saved into .presets/$file.preset" 
            else
                # print argument
                val=${arguments[$input]}

                if [[ ${#val} -ge 1 ]]; then
                    echo $val
                else
                    echo "invalid input"
                fi
            fi
            ;;
    esac
done
