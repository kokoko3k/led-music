#!/bin/bash
MAIN_DEVICE=alsa_output.usb-Focusrite_Scarlett_2i2_USB-00.analog-stereo

export IFS=$'\n'
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

list_descendants() {
    local children=$(ps -o pid= --ppid "$1")
    for pid in $children ; do
        list_descendants "$pid"
    done
    echo "$children"
}   



unload_modules(){
	#Elimina tutti i moduli Record-and-Play (potrebbero essere più di uno se lo script non è uscito bene in passato)
	for module in $(pacmd list-modules|grep -B5 -i 'Record-and-Play'|grep index|cut -d ":" -f 2) ; do
		pacmd unload-module $module
	done
	echo "done unload_modules"
}


#Clean function
finish() {
    echo ; echo TRAP: finish.

	unload_modules
	#ripristina il modulo module-stream-restore (occhio che non controllo che prima fosse attivo)
		pactl unload-module module-stream-restore
		pactl load-module module-stream-restore restore_device=true
    kill $ffpid
	#kill $(list_descendants $$)
	exit
}
trap finish INT TERM  QUIT 

#Pulizia iniziale
	unload_modules

#Dici a pulseaudio di non ripristinare i vecchi sink per le applicazioni conosciute:
	pactl unload-module module-stream-restore
	pactl load-module module-stream-restore restore_device=false

#Crea un dispositivo per catturare diverso dal monitor alsa, così che non sia influenzato dalla regolazione del volume:
	pacmd load-module module-combine-sink sink_name=record-n-play slaves=$MAIN_DEVICE sink_properties=device.description="Record-and-Play"  resample_method=auto
	pacmd set-default-sink record-n-play

#Muovi le stream già in play
	record_sync=$(pactl list short sinks|grep record-n-play |cut -s -f 1)
	for stream in $(pactl list short sink-inputs|grep -vi module-combine|cut -s -f 1) ; do
		pactl move-sink-input $stream $record_sync
	done


#ffmpeg -nostdin -y -loglevel quiet -fflags fastseek+flush_packets -flags low_delay -analyzeduration 0  -probesize 32 \
#	-framerate 50 \
#	-i $SCRIPT_DIR/vmeter.png \
#	-f pulse -ac 2 -i record-n-play.monitor \
#	-filter_complex \	"[1:a]showvolume=o=v:t=false:v=false:b=0:f=0:r=50:w=80:h=71:f=0:p=1:c=0x00000000,crop=h=65:w=115,scale=16:9,setpts=0.5*PTS[meter],[0:v][meter]overlay[out]" \
#	-map [out] \
#	 -pix_fmt rgb24 -vcodec rawvideo -f image2pipe - &

	 
#ffmpeg -nostdin -y  -loglevel quiet -fflags fastseek+flush_packets -flags low_delay -analyzeduration 0  -probesize 32 \
#	-f pulse -ac 2 -i record-n-play.monitor \
#	-filter_complex \	[0:a]showspectrum=fps=50:mode=combined:color=intensity:slide=scroll:s=1x9:win_func=blackman:saturation=1:start=2000:stop=7000,scale=16:9,tmix=frames=4,setpts=0.5*PTS[out] \
#	-map [out] \
#	 -pix_fmt rgb24 -vcodec rawvideo -f image2pipe - &


s=0.4 #similarity
b=0.1 #blend
ffmpeg -nostdin -y  -loglevel quiet -fflags fastseek+flush_packets -flags low_delay -analyzeduration 0  -probesize 32 \
	-f pulse -ac 2 -i record-n-play.monitor \
	-stream_loop -1 -i $SCRIPT_DIR/rainbow_swirl.avi \
	-filter_complex  [0:a]showspectrum=fps=50:mode=combined:color=intensity:slide=scroll:s=1x9:win_func=blackman:saturation=1:start=2000:stop=7000,scale=16:9,colorkey=color=ff0000:similarity=$s:blend=$b,tmix=frames=4,setpts=0.5*PTS[spectrum],[1:v]crop=out_w=2:out_h=9:x=0:y=0,scale=16:9,setpts=0.5*PTS[swirl],[swirl][spectrum]overlay[out] \
	-map [out] \
	 -pix_fmt rgb24 -vcodec rawvideo -f image2pipe - &
	 
	 
while true ; do 
	sleep 1
done

#Carino, facendo start e stop tra 3000 e 4000, interessante anche tra 2000 e 7000, probabilmente meglio.
#[0:a]showspectrum=fps=50:mode=combined:color=intensity:slide=scroll:s=16x9:win_func=blackman:saturation=1:start=3000:stop=4000,tmix=frames=5[out] \
#provare anche magma (non serve stringere le frequenze) e fiery in showspectrum come combinazione colore.
