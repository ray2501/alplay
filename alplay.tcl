#!/usr/bin/tclsh
#
# A very simple Tcl script to play music 
#

package require sndfile
package require mpg123
package require openal
package require tcltaglib

set bits 16
set channels 2
set samplerate 44100
set alformat AL_FORMAT_STEREO16
set isMp3 1

if {$argc == 1} {
    set name [lindex $argv 0]
} else {
    puts "Please give the correct argument!"
    exit
}

# Use tcltaglib to get file info
set filehandle [taglib::file_new $name]
if {[taglib::file_is_valid $filehandle] != 0} {
    set audioperp [taglib::audioproperties $filehandle]
    
    set length [lindex $audioperp 0]
    set bitrate [lindex $audioperp 1]
    set samplerate [lindex $audioperp 2]
    set channels [lindex $audioperp 3]
    
    puts "length: $length"
    puts "bitrate: $bitrate"
    puts "samplerate: $samplerate"
    puts "channels: $channels"
    
    set tag [taglib::file_tag $filehandle]
    set title [taglib::tag_title $tag]
    puts "Title: $title"
    
    set artist [taglib::tag_artist $tag]
    puts "Artist: $artist"

    set album [taglib::tag_album $tag]
    puts "Album: $album"

    set year [taglib::tag_year $tag]
    puts "Year: $year"
    
    taglib::tag_free $tag
    taglib::file_free $filehandle
}

# Check file extension
if {[string compare [string tolower [file extension $name]] ".mp3"] != 0} {
    if {[catch {set data [sndfile snd0 $name READ]}]} {
        puts "Read file failed."
        exit
    } else {
        set isMp3 0
        set encoding [dict get $data encoding]
    
        switch $encoding {
            {pcm_16} {
                    set bits 16
                }
                {pcm_24} {
                    set bits 24
                }
                {pcm_32} {
                    set bits 32
                }
                {pcm_s8} {
                    set bits 8
                }
                {pcm_u8} {
                    set bits 8
                }
                default {
                    set bits 16
                }
        }
    
        set channels [dict get $data channels]
        set samplerate [dict get $data samplerate]
        set size [expr [dict get $data frames] * $channels * $bits / 8]
        set buffersize [expr $samplerate * $bits / 8]
        snd0 buffersize $buffersize
        set buffer_number [expr $size / $buffersize + 1]
    }
} else {
        if {[catch {set data [mpg123 mpg0 $name]}]} {
        puts "Read file failed."
        exit
    } else {
        set bits [dict get $data bits]
        set channels [dict get $data channels]
        set samplerate [dict get $data samplerate]
        set size [expr [dict get $data length] * $channels * $bits / 8]
        set buffersize [expr $samplerate * $bits / 8]
        mpg0 buffersize $buffersize
        set buffer_number [expr $size / $buffersize + 1]
    }
}

openal::device dev0
dev0 setListener AL_POSITION [list 0 0 1.0]
dev0 setListener AL_VELOCITY [list 0 0 0]
dev0 setListener AL_ORIENTATION [list 0.0 0.0 1.0 0.0 1.0 0.0]
dev0 createSource
dev0 setSource AL_PITCH 1.0
dev0 setSource AL_GAIN  1.0
dev0 setSource AL_POSITION [list 0 0 1.0]
dev0 setSource AL_VELOCITY [list 0 0 0]
dev0 setSource AL_LOOPING 0

if {$channels > 1} {
    if {$bits == 8} {
        set alformat AL_FORMAT_STEREO8
    } else {
        set alformat AL_FORMAT_STEREO16
    }
} else {
    if {$bits == 8} {
        set alformat AL_FORMAT_MONO8
    } else {
        set alformat AL_FORMAT_MONO16
    }
}

# Load file data to our buffers
dev0 createBuffer $buffer_number
set buffer_index 0
while {$buffer_index < $buffer_number} {
    if {$isMp3==1} {
         if {[catch {set buffer [mpg0 read]}] == 0} {
             dev0 bufferData $alformat $buffer $samplerate $buffer_index
         } else {
             break
         }
    } else {
         if {[catch {set buffer [snd0 read_short]}] == 0} {
             dev0 bufferData $alformat $buffer $samplerate $buffer_index
         } else {
             break
         }
    }

    incr buffer_index
}

dev0 queueBuffers $buffer_index

# Just for test, get the total number of queued buffers
set buffer_index [dev0 getSource AL_BUFFERS_QUEUED]

set val 0
while {$val < $buffer_index} {
    dev0 playSource

    set state [dev0 getSource AL_SOURCE_STATE]
    while {[string compare $state "AL_PLAYING"]==0} {
        set state [dev0 getSource AL_SOURCE_STATE]
    }
    set val [dev0 getSource AL_BUFFERS_PROCESSED]
}

dev0 unqueueBuffers $buffer_index

dev0 destroySource
dev0 destroyBuffer
dev0 close

if {$isMp3==1} {
    mpg0 close
} else {
    snd0 close
} 
