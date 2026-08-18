#!/system/bin/sh
#########################################################################
#   AudioPlayback.sh
#   adb push AudioPlayback.sh /system/bin
#   chmod 755 /system/bin/AudioPlayback.sh
#########################################################################

#mode=`getprop debug.audiotest.mode`
#src=`getprop debug.audiotest.src`
#dst=`getprop debug.audiotest.dst`
echo "---AudioPlayback---"
dev=$1
mode=$2

LOG_TAG="PLAYBACK"
LOG_NAME="${0}:"

loge ()
{
  /system/bin/log -t $LOG_TAG -p e "$LOG_NAME $@"
}

logi ()
{
  /system/bin/log -t $LOG_TAG -p i "$LOG_NAME $@"
}

CODECPLAYBACKSTOP()
{
    if [ "$1" == "1" ]; then                               # Builtin_mic
			/system/bin/pkill agmcap
			/system/bin/tinymix 'TX DEC2 MUX' 'MSM_DMIC' > /dev/null 2>&1
			/system/bin/tinymix 'TX SMIC MUX2' 'ZERO' > /dev/null 2>&1
			/system/bin/tinymix 'TX_AIF1_CAP Mixer DEC2' '0'  > /dev/null 2>&1
			/system/bin/tinymix 'ADC1 ChMap' 'ZERO' > /dev/null 2>&1
			/system/bin/tinymix 'ADC1_MIXER Switch' '0'  > /dev/null 2>&1
			/system/bin/tinymix 'ADC1 Volume' '12' > /dev/null 2>&1
			/system/bin/tinymix 'TX_DEC2 Volume' '84' > /dev/null 2>&1
			echo "stop builtin_mic"
      logi "builtin_mic"
    elif [ "$1" == "2" ]; then                               # Sub mic
			/system/bin/pkill agmcap
			/system/bin/tinymix 'TX DEC0 MUX' 'MSM_DMIC'  > /dev/null 2>&1
			/system/bin/tinymix 'TX SMIC MUX0' 'ZERO' > /dev/null 2>&1
			/system/bin/tinymix 'TX_AIF1_CAP Mixer DEC0' '0' > /dev/null 2>&1
			/system/bin/tinymix 'ADC2 ChMap' 'ZERO' > /dev/null 2>&1
            /system/bin/tinymix 'ADC2_MIXER Switch' '0'> /dev/null 2>&1
            /system/bin/tinymix 'ADC2 MUX' 'INP2' > /dev/null 2>&1
			/system/bin/tinymix 'ADC2 Volume' '12' > /dev/null 2>&1
			/system/bin/tinymix 'TX_DEC0 Volume' '84' > /dev/null 2>&1
			echo "stop sub_mic"
			logi "sub_mic"
    elif [ "$1" == "3" ]; then                               #Receiver
			/system/bin/pkill agmplay
			/system/bin/tinymix 'aw_dev_2_prof' 'Music' > /dev/null 2>&1
			/system/bin/tinymix 'aw_dev_2_switch' 'Enable' > /dev/null 2>&1
			/system/bin/tinymix 'aw_dev_3_switch' 'Enable' > /dev/null 2>&1
			echo "stop receiver"
			logi "receiver"
    elif [ "$1" == "4" ]; then                               #Bottom_Speaker
			/system/bin/pkill agmplay
			/system/bin/tinymix 'aw_dev_2_switch' 'Enable' > /dev/null 2>&1
			/system/bin/tinymix 'aw_dev_3_switch' 'Enable' > /dev/null 2>&1
			echo "stop bottom_speaker"
			logi "bottom_speaker"
    elif [ "$1" == "5" ]; then                               #Top_Speaker
			/system/bin/tinymix 'aw_dev_2_prof' 'Music' > /dev/null 2>&1
			/system/bin/tinymix 'aw_dev_2_switch' 'Enable' > /dev/null 2>&1
			/system/bin/tinymix 'aw_dev_3_switch' 'Enable' > /dev/null 2>&1
			echo "stop top_speaker"
			logi "top_speaker"
    else
    	echo "stop exit"
			logi "1 exit 0"
			exit 0
    fi
}

CODECPLAYBACK()
{
    if [ "$1" == "1" ]; then                               # Builtin_mic
			rm /cache/main-mic.wav > /dev/null 2>&1
			/system/bin/tinymix 'TX DEC2 MUX' 'SWR_MIC' > /dev/null 2>&1
			/system/bin/tinymix 'TX SMIC MUX2' 'SWR_MIC5' > /dev/null 2>&1
			/system/bin/tinymix 'TX_AIF1_CAP Mixer DEC2' '1'  > /dev/null 2>&1
			/system/bin/tinymix 'ADC1 ChMap' 'SWRM_TX2_CH2' > /dev/null 2>&1
			/system/bin/tinymix 'ADC1_MIXER Switch' '1'  > /dev/null 2>&1
			/system/bin/tinymix 'ADC1 Volume' '8' > /dev/null 2>&1
			/system/bin/tinymix 'TX_DEC2 Volume' '75' > /dev/null 2>&1
			agmcap /cache/amic1.wav -D 100 -d 101 -T 5 -c 2 -r 48000 -i CODEC_DMA-LPAIF_RXTX-TX-3 > /dev/null 2>&1 &
			echo "builtin_mic"
			logi "builtin_mic"
    elif [ "$1" == "2" ]; then                               # Sub_mic
			rm /cache/sub-mic.wav > /dev/null 2>&1
			/system/bin/tinymix 'TX DEC0 MUX' 'SWR_MIC'  > /dev/null 2>&1
			/system/bin/tinymix 'TX SMIC MUX0' 'SWR_MIC4' > /dev/null 2>&1
			/system/bin/tinymix 'TX_AIF1_CAP Mixer DEC0' '1' > /dev/null 2>&1
			/system/bin/tinymix 'ADC2 ChMap' 'SWRM_TX2_CH1' > /dev/null 2>&1
            /system/bin/tinymix 'ADC2_MIXER Switch' '1'> /dev/null 2>&1
            /system/bin/tinymix 'ADC2 MUX' 'INP3' > /dev/null 2>&1
			/system/bin/tinymix 'ADC2 Volume' '8' > /dev/null 2>&1
			/system/bin/tinymix 'TX_DEC0 Volume' '75' > /dev/null 2>&1
			agmcap /cache/amic3.wav -D 100 -d 101 -T 5 -c 2 -r 48000 -i CODEC_DMA-LPAIF_RXTX-TX-3 > /dev/null 2>&1 &
			echo "sub_mic"
			logi "sub_mic"
    elif [ "$1" == "3" ]; then                               #Receiver
			/system/bin/tinymix 'aw_dev_0_prof' 'Receiver' > /dev/null 2>&1
			/system/bin/tinymix 'aw_dev_0_switch' 'Enable' > /dev/null 2>&1
			/system/bin/tinymix 'aw_dev_1_switch' 'Disable' > /dev/null 2>&1
			agmplay /vendor/etc/receiver.wav -D 100 -d 100 -i MI2S-LPAIF_VA-RX-PRIMARY > /dev/null 2>&1 &
			echo "receiver"
			logi "receiver"
    elif [ "$1" == "4" ]; then                               #Bottom_Speaker
			/system/bin/tinymix 'aw_dev_0_switch' 'Disable' > /dev/null 2>&1
			/system/bin/tinymix 'aw_dev_1_switch' 'Enable' > /dev/null 2>&1
			agmplay /vendor/etc/buttom-speaker.wav -D 100 -d 100 -i MI2S-LPAIF_VA-RX-PRIMARY > /dev/null 2>&1 &
			echo "bottom_speaker"
			logi "bottom_speaker"
    elif [ "$1" == "5" ]; then                               #Top_Speaker
			/system/bin/tinymix 'aw_dev_0_prof' 'Music' > /dev/null 2>&1
			/system/bin/tinymix 'aw_dev_0_switch' 'Enable' > /dev/null 2>&1
			/system/bin/tinymix 'aw_dev_1_switch' 'Disable' > /dev/null 2>&1
			agmplay /vendor/etc/top-speaker.wav -D 100 -d 100 -i MI2S-LPAIF_VA-RX-PRIMARY > /dev/null 2>&1 &
			echo "top_speaker"
			logi "top_speaker"
    else
    	echo "play exit"
			logi "1 exit 0"
			exit 0
    fi
}

case $mode in
    "0")
        #CODEC playback stop
        CODECPLAYBACKSTOP $dev
        logi "stop PLAYBACK"
    ;;
    "1")
        #codec playback start
        CODECPLAYBACK $dev
        logi "start PLAYBACK"
    ;;
esac
