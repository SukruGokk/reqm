# Request Manager
# Bash version: 5.2.21(1)-release
# 26/01/2024

# main args
declare -A arguments=(["method"]="GET" ["url"]="None" ["headers"]="Content-Type: text/plain" ["data"]='None' ["output"]="None")

# associative array for query parameters
declare -A query_params

# user defined variables
declare -A variables

while true
do
    echo
    read -p $'\e[1;92mreqm>\e[0m ' input
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
            echo ""
            echo "use <key>=<value> structure to set arguments or define variables"
            echo "use variables with \$, ex: data=\$user_data"
            echo "use query.<variable name> to define query data, ex: query.username=admin"
            echo "for multiple headers use \",\" ex: headers=Content-Type: text/plain, Authorization: Basic <token>"
            ;;
        exit)
            exit
            ;;
        send)
            # build query string from query_params associative array
            query_string=""
            first=true
            for key in "${!query_params[@]}"; do
                if $first; then
                    query_string="${key}=${query_params[$key]}"
                    first=false
                else
                    query_string+="&${key}=${query_params[$key]}"
                fi
            done

            # append query string to URL if method is GET and query_string not empty
            if [[ "${arguments[method]}" == "GET" && -n "$query_string" ]]; then
                if [[ "${arguments[url]}" == *"?"* ]]; then
                    arguments[url]+="&${query_string}"
                else
                    arguments[url]+="?${query_string}"
                fi
            fi

            # build curl command string
            string='curl -s -w "%{http_code}" ${arguments[url]} -X ${arguments[method]}'

            # add data if method is not GET and data is not None
            if [[ ! "${arguments[data]}" = "None" && "${arguments[method]}" != "GET" ]]; then
                string+=" -d '${arguments[data]}'"
            fi

            # add headers
            if [[ ! "${arguments[headers]}" = "None" ]]; then
                IFS=',' read -r -a array <<< "${arguments[headers]}"
                for header in "${array[@]}"
                do
                    string+=" -H \"$(echo $header | xargs)\""
                done
            fi

            # execute curl command
            echo "$string"
            response=$(eval $string)

            # separate http code and content
            http_code=${response:${#response}-3}
            content=${response:0:${#response}-3}
            output="${arguments[output]}"

            # write content to file if output specified
            if [[ ${#output} -gt 4 ]]; then
                output="$(echo $output | tr -d ' ')"
                echo "$content" > "$output"
            fi

            # print status and body
            echo "status code: $http_code"
            echo "response body: $content"
            ;;
        args)
	# print arguments and query_params
	for i in "${!arguments[@]}"
	do
	    echo "$i: ${arguments[$i]}"
	done

	if [ ${#query_params[@]} -eq 0 ]; then
	    echo "query parameters: None"
	else
	    echo "query parameters:"
	    for i in "${!query_params[@]}"
	    do
		echo "  $i = ${query_params[$i]}"
	    done
	fi
	;;
        *)
            # empty input
            if [[ ! ${#input} -ge 1 ]]; then
                echo "invalid input"

            # if input contains '=' (assignment)
            elif [[ $input = *"="* ]]; then
                key=$(echo $input | cut -d'=' -f 1)
                value=$(echo $input | cut -d'=' -f 2-)

                # variable substitution if value starts with $
                if [[ $value = \$* ]]; then
                    varname="${value:1}"
                    if [[ -n "${variables[$varname]}" ]]; then
                        value="${variables[$varname]}"
                    else
                        echo "variable $varname not defined"
                        continue
                    fi
                fi

                # if key starts with 'query.' put in query_params
                if [[ $key == query.* ]]; then
                    qkey="${key#query.}"
                    query_params["$qkey"]="$value"
                # if key is known argument key, set in arguments
                elif [[ -v "arguments[$key]" ]]; then
                    arguments[$key]="$value"
                else
                    # if key or value invalid, print error
                    if [[ ! ${#key} -ge 1 ]] || [[ ! ${#value} -ge 1 ]]; then
                        echo "invalid input"
                    else
                        # define as user variable
                        variables["$key"]="$value"
                    fi
                fi
            # print user defined variable if input matches
            elif [[ -n ${variables[${input}]} ]]; then
                echo "${variables[${input}]}"
            # load saved request
            elif [[ $input == load* ]]; then
                file=$(echo $input | cut -d' ' -f 2)
                if [[ ! -f ".presets/$file.preset" ]]; then
                    echo "preset file not found"
                    continue
                fi
                IFS=$'\n'
                unset query_params
                declare -A query_params
                for LINE in $(cat ".presets/$file.preset")
                do
                    key=$(echo $LINE | cut -d'½' -f 1)
                    value=$(echo $LINE | cut -d'½' -f 2)

                    # distinguish query params and arguments by prefix
                    if [[ $key == query.* ]]; then
                        qkey="${key#query.}"
                        query_params["$qkey"]="$value"
                    else
                        arguments[$key]="$value"
                    fi
                done
                echo "values are imported from $file"
            # save current request
            elif [[ $input == save* ]]; then
                file=$(echo $input | cut -d' ' -f 2)
                mkdir -p ".presets"
                > ".presets/$file.preset"
                # save arguments
                for i in "${!arguments[@]}"
                do
                    echo "$i½${arguments[$i]}" >> ".presets/$file.preset"
                done
                # save query params with prefix
                for i in "${!query_params[@]}"
                do
                    echo "query.$i½${query_params[$i]}" >> ".presets/$file.preset"
                done
                echo "variables saved into .presets/$file.preset"
            else
                # print argument or query param value
                if [[ -v "arguments[$input]" ]]; then
                    echo "${arguments[$input]}"
                elif [[ -v "query_params[$input]" ]]; then
                    echo "${query_params[$input]}"
                else
                    echo "invalid input"
                fi
            fi
            ;;
    esac
done
