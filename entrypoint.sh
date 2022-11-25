# Wait for the container to fully initialize
sleep 1

# Default the TZ environment variable to UTC.
# TZ=${TZ:-UTC}
# export TZ

# Set environment variable that holds the Internal Docker IP
# INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
# export INTERNAL_IP

# Switch to the container's working directory
export HOME=/home/container
cd /home/container || exit 1

# Download and install SteamCMD
# mkdir -p tmp
# cd /tmp
# curl -sSL -o steamcmd.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
# tar -xzvf steamcmd.tar.gz -C /home/container/steamcmd
# cd /home/container

./steamcmd/steamcmd.sh +force_install_dir /mnt/server "+login \"${STEAM_USER}\" \"${STEAM_PASS}\"" +app_update ${STEAMCMD_APPID} validate +quit
echo -e "\nUPDATE CHECK COMPLETE!\n"
exit 0
