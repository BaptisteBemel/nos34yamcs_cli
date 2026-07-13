#!/bin/bash  
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )  
source "$SCRIPT_DIR/env.sh"  

NOS3_UID=$(stat -c '%u' "$SCRIPT_DIR/env.sh")
NOS3_GID=$(stat -c '%g' "$SCRIPT_DIR/env.sh")
  
export SC_NUM="sc_1"  
export SC_NETNAME="nos3_"$SC_NUM  
export SC_CFG_FILE="-f nos3-simulator.xml"  
export GND_CFG_FILE="-f nos3-simulator.xml"  
  
# Dossiers de données  
echo "Make data folders..."  
mkdir -p \
  "$FSW_DIR/data/cam" \
  "$FSW_DIR/data/evs" \
  "$FSW_DIR/data/hk" \
  "$FSW_DIR/data/inst" \
  /tmp/nos3/data/cam \
  /tmp/nos3/data/evs \
  /tmp/nos3/data/hk \
  /tmp/nos3/data/inst \
  /tmp/nos3/uplink 
cp "$BASE_DIR/fsw/build/exe/cpu1/cf/cfe_es_startup.scr" /tmp/nos3/uplink/tmp0.so 
cp "$BASE_DIR/fsw/build/exe/cpu1/cf/sample.so" /tmp/nos3/uplink/tmp1.so
  
# Réseau core  
echo "Create ground networks..."  
if ! docker network inspect nos3_core >/dev/null 2>&1; then
  $DNETWORK create \
    --driver=bridge \
    --subnet=192.168.41.0/24 \
    --gateway=192.168.41.1 \
    nos3_core
fi
echo ""  
  
# NOS interfaces sur nos3_core  
echo "Create NOS interfaces..."  
docker run -di -v $SIM_DIR:$SIM_DIR --name "nos_terminal"     --network=nos3_core -w $SIM_BIN $DBOX ./nos3-single-simulator $GND_CFG_FILE stdio-terminal  
docker run -di -v $SIM_DIR:$SIM_DIR --name "nos_udp_terminal" --network=nos3_core -w $SIM_BIN $DBOX ./nos3-single-simulator $GND_CFG_FILE udp-terminal  
echo ""  
  
# Réseau spacecraft  
echo "Create spacecraft network..."  
if ! docker network inspect "$SC_NETNAME" >/dev/null 2>&1; then
  $DNETWORK create "$SC_NETNAME"
fi
echo ""  
  
# 42 Dynamics Engine  
echo "42 Dynamics..."  
rm -rf $USER_NOS3_DIR/42/NOS3InOut  
cp -r $BASE_DIR/cfg/build/InOut $USER_NOS3_DIR/42/NOS3InOut  
docker run -di -v $USER_NOS3_DIR:$USER_NOS3_DIR --name $SC_NUM"_fortytwo" -h fortytwo --network=$SC_NETNAME -w $USER_NOS3_DIR/42 $DBOX $USER_NOS3_DIR/42/42 NOS3InOut  
echo ""  
  
# Flight Software  
echo "Flight Software..."  
docker run -dit \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -u "$NOS3_UID:$NOS3_GID" \
  -e TERM=xterm \
  -v $BASE_DIR:$BASE_DIR \
  --name $SC_NUM"_nos_fsw" \
  -h nos-fsw \
  --network=$SC_NETNAME \
  --network-alias=nos-fsw \
  -w $FSW_DIR \
  --sysctl fs.mqueue.msg_max=10000 \
  --ulimit rtprio=99 \
  --cap-add=sys_nice \
  $DBOX \
  $SCRIPT_DIR/fsw/fsw_respawn.sh
echo ""  
  
# NOS Engine Server + simulateurs  
echo "Simulators..."  
docker run -di \
  -v "$SIM_DIR:$SIM_DIR" \
  --name "${SC_NUM}_nos_engine_server" \
  -h nos-engine-server \
  --network="$SC_NETNAME" \
  --network-alias=nos-engine-server \
  --network-alias=nos_engine_server \
  --network-alias=sc01-nos-engine-server \
  -w "$SIM_BIN" \
  "$DBOX" \
  /usr/bin/nos_engine_server_standalone \
  -f "$SIM_BIN/nos_engine_server_config.json"  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_truth42sim"        -h truth42sim        --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE truth42sim  
  
# Connecter nos_terminal au réseau spacecraft  
$DNETWORK connect $SC_NETNAME nos_terminal  
$DNETWORK connect $SC_NETNAME nos_udp_terminal  
  
# Simulateurs de composants  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_cam_sim"      --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE camsim  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_css_sim"      --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE generic-css-sim  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_eps_sim"      --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE generic-eps-sim  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_fss_sim"      --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE generic-fss-sim  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_gps_sim"      --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE gps  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_imu_sim"      --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE generic-imu-sim  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_mag_sim"      --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE generic-mag-sim  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_rw_sim0"      --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE generic-reactionwheel-sim0  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_rw_sim1"      --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE generic-reactionwheel-sim1  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_rw_sim2"      --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE generic-reactionwheel-sim2  
docker run -di \
  -v "$SIM_DIR:$SIM_DIR" \
  --name "${SC_NUM}_radio_sim" \
  -h radio-sim \
  --network="$SC_NETNAME" \
  --network-alias=radio-sim \
  --network-alias=radio_sim \
  --network-alias=active-gs \
  -p 8010:8010/udp \
  -w "$SIM_BIN" \
  "$DBOX" \
  ./nos3-single-simulator \
  $SC_CFG_FILE \
  generic-radio-sim
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_sample_sim"   --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE sample-sim  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_startrk_sim"  --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE generic-star-tracker-sim  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_thruster_sim" --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE generic-thruster-sim  
docker run -di -v $SIM_DIR:$SIM_DIR --name $SC_NUM"_torquer_sim"  --network=$SC_NETNAME -w $SIM_BIN $DBOX ./nos3-single-simulator $SC_CFG_FILE generic-torquer-sim  
echo ""  
  
# NOS Time Driver — lancé EN DERNIER avec sleep 8, sur nos3_core  
echo "NOS Time Driver..."  
sleep 8  
docker create -it \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -u "$NOS3_UID:$NOS3_GID" \
  -e TERM=xterm \
  -v $SIM_DIR:$SIM_DIR \
  --name nos_time_driver \
  --network=nos3_core \
  -w $SIM_BIN \
  $DBOX \
  ./nos3-single-simulator \
  $GND_CFG_FILE \
  time

$DNETWORK connect \
  --alias nos-time-driver \
  --alias nos_time_driver \
  $SC_NETNAME \
  nos_time_driver

docker start nos_time_driver     
echo ""  
  
echo "Headless launch complete!"  
echo "Check running containers:"
docker ps -a
