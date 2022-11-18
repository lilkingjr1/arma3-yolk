#!/bin/bash

## File: Pterodactyl Arma 3 Image - entrypoint.sh
## Author: David Wolfe (Red-Thirten)
## Contributors: Aussie Server Hosts (https://aussieserverhosts.com/), Stephen White (SilK)
## Date: 2022/05/22
## License: MIT License

# === ENTRYPOINT START ===

# Wait for the container to fully initialize
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

./steamcmd/steamcmd.sh +force_install_dir /home/container +login ${STEAM_USER} ${STEAM_PASS} +app_update ${STEAMCMD_APPID} $( [[ -z ${VALIDATE_SERVER} ]] || printf %s "validate" ) +quit
echo -e "\nUPDATE CHECK COMPLETE!\n"
exit 0

# Check for old eggs
if [[ -z ${VALIDATE_SERVER} ]]; then # VALIDATE_SERVER was not in the previous version
    echo -e "\n${RED}[STARTUP_ERR]: Please contact your administrator/host for support, and give them the following message:${NC}\n"
    echo -e "\t${CYAN}Your Arma 3 Egg is outdated and no longer supported.${NC}"
    echo -e "\t${CYAN}Please download the latest version at the following link, and install it in your panel:${NC}"
    echo -e "\t${CYAN}${EGG_URL}${NC}\n"
    exit 1
fi

# Collect and parse all specified mods
if [[ -n ${MODIFICATIONS} ]] && [[ ${MODIFICATIONS} != *\; ]]; then # Add manually specified mods to the client-side mods list, while checking for trailing semicolon
    CLIENT_MODS="${MODIFICATIONS};"
else
    CLIENT_MODS=${MODIFICATIONS}
fi
if [[ -f ${MOD_FILE} ]] && [[ -n "$(cat ${MOD_FILE} | grep 'Created by Arma 3 Launcher')" ]]; then # If the mod list file exists and is valid, parse and add mods to the client-side mods list
    CLIENT_MODS+=$(cat ${MOD_FILE} | grep 'id=' | cut -d'=' -f3 | cut -d'"' -f1 | xargs printf '@%s;')
elif [[ -n "${MOD_FILE}" ]]; then # If MOD_FILE is not null, warn user file is missing or invalid
    echo -e "\n${YELLOW}[STARTUP_WARN]: Arma 3 Modlist file \"${CYAN}${MOD_FILE}${YELLOW}\" could not be found, or is invalid!${NC}"
    echo -e "\tEnsure your uploaded modlist's file name matches your Startup Parameter."
    echo -e "\tOnly files exported from an Arma 3 Launcher are permitted."
    if [[ -n "${CLIENT_MODS}" ]]; then
        echo -e "\t${CYAN}Reverting to the manual mod list...${NC}"
    fi
fi
if [[ -n ${SERVERMODS} ]] && [[ ${SERVERMODS} != *\; ]]; then # Add server mods to the master mods list, while checking for trailing semicolon
    allMods="${SERVERMODS};"
else
    allMods=${SERVERMODS}
fi
if [[ -n ${OPTIONALMODS} ]] && [[ ${OPTIONALMODS} != *\; ]]; then # Add specified optional mods to the mods list, while checking for trailing semicolon
    allMods+="${OPTIONALMODS};"
else
    allMods+=${OPTIONALMODS}
fi
allMods+=$CLIENT_MODS # Add all client-side mods to the master mod list
CLIENT_MODS=$(RemoveDuplicates ${CLIENT_MODS}) # Remove duplicate mods from CLIENT_MODS, if present
allMods=$(RemoveDuplicates ${allMods}) # Remove duplicate mods from allMods, if present
allMods=$(echo $allMods | sed -e 's/;/ /g') # Convert from string to array

# Update everything (server and mods), if specified
if [[ ${UPDATE_SERVER} == 1 ]]; then
    echo -e "\n${GREEN}[STARTUP]: ${CYAN}Starting checks for all updates...${NC}"
    echo -e "(It is okay to ignore any \"SDL\" errors during this process)\n"

    ## Update game server
    echo -e "${GREEN}[UPDATE]:${NC} Checking for game server updates with App ID: ${CYAN}${STEAMCMD_APPID}${NC}..."

    if [[ ${VALIDATE_SERVER} == 1 ]]; then # Validate will be added as a parameter if specified
        echo -e "\t${CYAN}File validation enabled.${NC} (This may take extra time to complete)"
        validateServer="validate"
    else
        validateServer=""
    fi

    # Determine what extra flags should be set
    if [[ -n ${STEAMCMD_EXTRA_FLAGS} ]]; then
        echo -e "\t(${YELLOW}Advanced${NC}) Extra SteamCMD flags specified: ${CYAN}${STEAMCMD_EXTRA_FLAGS}${NC}\n"
        extraFlags=${STEAMCMD_EXTRA_FLAGS}
    elif [[ ${CDLC} == 1 ]]; then
        echo -e "\t${CYAN}Download/Update Creator DLC server files enabled.${NC}\n"
        extraFlags="-beta creatordlc"
    else
        echo -e ""
        extraFlags=""
    fi

    RunSteamCMD 0 ${STEAMCMD_APPID}

    ## Update mods
    if [[ -n $allMods ]] && [[ ${DISABLE_MOD_UPDATES} != 1 ]]; then
        echo -e "\n${GREEN}[UPDATE]:${NC} Checking all ${CYAN}Steam Workshop mods${NC} for updates..."
        for modID in $(echo $allMods | sed -e 's/@//g')
        do
            if [[ $modID =~ ^[0-9]+$ ]]; then # Only check mods that are in ID-form
                # If a mod is defined in OPTIONALMODS, and is not defined in CLIENT_MODS or SERVERMODS, then treat as an optional mod
                # Optional mods are given a different directory which is checked to see if a new update is available. This is to ensure
                # if an optional mod is switched to be a standard client-side mod, this script will redownload the mod
                if [[ "${OPTIONALMODS}" == *"@${modID};"* ]] && [[ "${CLIENT_MODS}" != *"@${modID};"* ]] && [[ "${SERVERMODS}" != *"@${modID};"* ]]; then
                    modType=2
                    modDir=@${modID}_optional
                else
                    modType=1
                    modDir=@${modID}
                fi

                # Get mod's latest update in epoch time from its Steam Workshop changelog page
                latestUpdate=$(curl -sL https://steamcommunity.com/sharedfiles/filedetails/changelog/$modID | grep '<p id=' | head -1 | cut -d'"' -f2)

                # If the update time is valid and newer than the local directory's creation date, or the mod hasn't been downloaded yet, download the mod
                if [[ ! -d $modDir ]] || [[ ( -n $latestUpdate ) && ( $latestUpdate =~ ^[0-9]+$ ) && ( $latestUpdate > $(find $modDir | head -1 | xargs stat -c%Y) ) ]]; then
                    # Get the mod's name from the Workshop page as well
                    modName=$(curl -sL https://steamcommunity.com/sharedfiles/filedetails/changelog/$modID | grep 'workshopItemTitle' | cut -d'>' -f2 | cut -d'<' -f1)
                    if [[ -z $modName ]]; then # Set default name if unavailable
                        modName="[NAME UNAVAILABLE]"
                    fi
                    if [[ ! -d $modDir ]]; then
                        echo -e "\n${GREEN}[UPDATE]:${NC} Downloading new Mod: \"${CYAN}${modName}${NC}\" (${CYAN}${modID}${NC})"
                    else
                        echo -e "\n${GREEN}[UPDATE]:${NC} Mod update found for: \"${CYAN}${modName}${NC}\" (${CYAN}${modID}${NC})"
                    fi
                    if [[ -n $latestUpdate ]] && [[ $latestUpdate =~ ^[0-9]+$ ]]; then # Notify last update date, if valid
                        echo -e "\tMod was last updated: ${CYAN}$(date -d @${latestUpdate})${NC}"
                    fi
                    echo -e "\tAttempting mod update/download via SteamCMD...\n"

                    RunSteamCMD $modType $modID
                fi
            fi
        done

        # Check over key files for unconfigured optional mods' .bikey files
        for keyFile in $(find ./keys -name "*.bikey" -type f); do
            keyFileName=$(basename ${keyFile})

            # If the key file is using the optional mod file name
            if [[ "${keyFileName}" == "optional_"* ]]; then
                modID=$(echo "${keyFileName}" | cut -d _ -f 2)

                # If mod is not in optional mods, delete it
                # If a mod is configured in CLIENT_MODS or SERVERMODS, we should still delete this file
                # as a new file will have been copied that does not follow the naming scheme
                if [[ "${OPTIONALMODS}" != *"@${modID};"* ]]; then

                    # We only need to let the user know the key file is being deleted if this mod is no longer configured at all.
                    # If CLIENT_MODS contains the mod ID, we'd just confuse the user by telling them we are deleting the optional .bikey file
                    if [[ "${CLIENT_MODS}" != *"@${modID};"* ]]; then
                        echo -e "\tKey file and directory for unconfigured optional mod ${CYAN}${modID}${NC} is being deleted..."
                    fi

                    # Delete the optional mod .bikey file and directory
                    rm ${keyFile}
                    rmdir ./@${modID}_optional 2> /dev/null
                fi
            fi
        done;

        echo -e "${GREEN}[UPDATE]:${NC} Steam Workshop mod update check ${GREEN}complete${NC}!"
    fi
fi

# Check if specified server binary exists.
if [[ ! -f ./${SERVER_BINARY} ]]; then
    echo -e "\n${RED}[STARTUP_ERR]: Specified Arma 3 server binary could not be found in the root directory!${NC}"
    echo -e "${YELLOW}Please do the following to resolve this issue:${NC}"
    echo -e "\t${CYAN}- Double check your \"Server Binary\" Startup Variable is correct.${NC}"
    echo -e "\t${CYAN}- Ensure your server has properly installed/updated without errors (reinstalling/updating again may help).${NC}"
    echo -e "\t${CYAN}- Use the File Manager to check that your specified server binary file is not missing from the root directory.${NC}\n"
    exit 1
fi

# Make mods lowercase, if specified
if [[ ${MODS_LOWERCASE} == "1" ]]; then
    for modDir in $allMods
    do
        ModsLowercase $modDir
    done
fi

# Clear HC cache, if specified
if [[ ${CLEAR_CACHE} == "1" ]]; then
    echo -e "\n${GREEN}[STARTUP]: ${CYAN}Clearing Headless Client profiles cache...${NC}"
    for profileDir in ./serverprofile/home/*
    do
        [ "$profileDir" = "./serverprofile/home/Player" ] && continue
        rm -rf $profileDir
    done
fi

# Check if basic.cfg exists, and download if not (Arma really doesn't like it missing for some reason)
if [[ ! -f ./basic.cfg ]]; then
    echo -e "\n${YELLOW}[STARTUP_WARN]: Basic Network Configuration file \"${CYAN}basic.cfg${YELLOW}\" is missing!${NC}"
    echo -e "\t${YELLOW}Downloading default file for use instead...${NC}"
    curl -sSL ${BASIC_URL} -o ./basic.cfg
fi

# Setup NSS Wrapper for use ($NSS_WRAPPER_PASSWD and $NSS_WRAPPER_GROUP have been set by the Dockerfile)
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
envsubst < /passwd.template > ${NSS_WRAPPER_PASSWD}

if [[ ${SERVER_BINARY} == *"x64"* ]]; then # Check which libnss-wrapper architecture to run, based off the server binary name
    export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libnss_wrapper.so
else
    export LD_PRELOAD=/usr/lib/i386-linux-gnu/libnss_wrapper.so
fi

# Replace Startup Variables
modifiedStartup=`eval echo $(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')`

# Start Headless Clients if applicable
if [[ ${HC_NUM} > 0 ]]; then
    echo -e "\n${GREEN}[STARTUP]:${NC} Starting ${CYAN}${HC_NUM}${NC} Headless Client(s)."
    for i in $(seq ${HC_NUM})
    do
        if [[ ${HC_HIDE} == "1" ]];
        then
            ./${SERVER_BINARY} -client -connect=127.0.0.1 -port=${SERVER_PORT} -password="${SERVER_PASSWORD}" -profiles=./serverprofile -bepath=./battleye -mod="${CLIENT_MODS}" ${STARTUP_PARAMS} > /dev/null 2>&1 &
        else
            ./${SERVER_BINARY} -client -connect=127.0.0.1 -port=${SERVER_PORT} -password="${SERVER_PASSWORD}" -profiles=./serverprofile -bepath=./battleye -mod="${CLIENT_MODS}" ${STARTUP_PARAMS} &
        fi
        echo -e "${GREEN}[STARTUP]:${CYAN} Headless Client $i${NC} launched."
    done
fi

# Start the Server
echo -e "\n${GREEN}[STARTUP]:${NC} Starting server with the following startup command:"
echo -e "${CYAN}${modifiedStartup}${NC}\n"
${modifiedStartup}

if [ $? -ne 0 ]; then
    echo -e "\n${RED}PTDL_CONTAINER_ERR: There was an error while attempting to run the start command.${NC}\n"
    exit 1
fi
