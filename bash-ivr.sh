#! /bin/bash

# Name:
#    IVR - Interactive Voice Response.
# Author:
#    Karl Mowatt-Wilson - http://mowson.org/karl
# Description:
#    Present a menu system in the form of spoken voice prompts.
#    The menu structure and targets (menu endpoints) are defined by files
#    named according to a standard.
# History:
#  2016-01-02 - KMW
#             - first version about now.
#             - basically working to navigate menus, but not yet speaking.
#  2016-01-17 - KMW
#             - change to using bash, so I can do substrings and
#               non-blocking reads.
#             - rewrite to not pipe things into while loop, since that was
#               preventing reading keyboard inside the loop.
#  2016-01-27 - KMW
#             - play soundfiles and TTS.
#             - add debug/warn/info functions.
#             - allow menu speeches to be interrupted.
#             - fix broken stuff...
#  2016-03-13 - KMW
#             - tidy and put into git
#  2016-03-29 - KMW
#             - add command-line option parsing.

#==========================================================================
# CONFIG
#==========================================================================

# Define the directory holding the menu structure files.
MENU="${0%/*}/examples/menu"
SOUNDS="${0%/*}/sounds"

# Define the wav player program - can specify full path and commandline
# options if desired.
PLAYWAV="play"

# Define the TextToSpeech program - can specify full path and commandline
# options if desired.
TTS="flite -t"

# CODE stores the current position in the menu structure.
# eg. "31" if we have chosen the 3rd top-level menu and the 1st item under
# that.
# If we are at top level, CODE is empty.
CODE=""

# KEYQUEUE holds any unprocessed keystrokes
KEYQUEUE=""

# DEBUG_LEVEL:
#  0 = all debug messages
#  1 = warnings
#  2 = info
DEBUG_LEVEL=2


#==========================================================================
# FUNCTIONS
#==========================================================================
Error() {
   echo "ERROR: $1" 1>&2
}

#--------------------------------------------------------------------------
Debug() {
   [ $DEBUG_LEVEL -le 0 ] && echo "DEBUG: $1" 1>&2
}

#--------------------------------------------------------------------------
Warning() {
   [ $DEBUG_LEVEL -le 1 ] && echo "WARNING: $1" 1>&2
}

#--------------------------------------------------------------------------
Info() {
   [ $DEBUG_LEVEL -le 2 ] && echo "INFO: $1" 1>&2
}

#--------------------------------------------------------------------------
CheckSetup() {
   # this is a fatal error:
   [ -d "$MENU" ] || {
      Error "CheckSetup: MENU dir not found '$MENU'"
      exit 1
   }
   [ -r "$SOUNDS/1.wav" ] || {
      Error "CheckSetup: one or more digit wav files not found in '$SOUNDS'"
      exit 1
   }

   # this is potentially deliberate, possibly.  Not necessarily fatal?
   [ -r "$SOUNDS/menuheader.wav" ] \
      || Warning "CheckSetup: menuheader.wav not found in '$SOUNDS'"
}

#--------------------------------------------------------------------------
PlaySound() {
   local SOUNDFILE=$1
   if [ "$SOUNDFILE" = "" ]; then
      Error "PlaySound: trying to play unspecified file!"
   elif [ ! -r "$SOUNDFILE" ]; then
      Error "PlaySound: trying to play unreadable file!  '$SOUNDFILE'"
   else
      Info "PlaySound: playing '$SOUNDFILE'"
      $PLAYWAV "$SOUNDFILE"
   fi
}

#--------------------------------------------------------------------------
SpeakTTS() {
   local SPEECH=$1
   if [ "$SPEECH" = "" ]; then
      Error "SpeakTTS: trying to speak empty string"
   else
      Info "SpeakTTS: speaking '$SPEECH'"
      $TTS "$SPEECH"
   fi
}

#--------------------------------------------------------------------------
ListTargetCodes() {
   local CODE=$1
   local KEY=$2
   if [ "$KEY" = "" ]; then
      KEY='[0-9]+'
   fi
   local RGX="^$CODE${KEY}([^1-9]+.*)?\.(menu|sh|wav)$"
   ls "$MENU" | sed -nr "/$RGX/ {s/[^1-9].*//; p}" | sort -u
}

#--------------------------------------------------------------------------
SpeakTarget() {
   local CODE=$1
   local DIGIT=$2
   local KEYPRESS=""

   # NOTE: the space before the -1 on the next line is required!
   #local DIGIT="${CODE: -1}"
   Debug "SpeakTarget: CODE='$CODE' DIGIT='$DIGIT' KEYQUEUE='$KEYQUEUE'"

   case $DIGIT in
      0)
         read -t 0.1 -n 1 -s KEYPRESS
         KEYQUEUE=$KEYQUEUE$KEYPRESS
         if [ ! "$KEYQUEUE" ]; then
            PlaySound "$SOUNDS/menuheader.wav"
         else
            Debug "SpeakTarget MenuHeader early exit: CODE='$CODE' DIGIT='$DIGIT' KEYQUEUE='$KEYQUEUE'"
         fi
         ;;
      1|2|3|4|5|6|7|8|9)
         local KEYAUDIO="${DIGIT}.wav"
         local RGX="^${CODE}${DIGIT}_[^.]+\.wav$"
         local AUDIO="$(ls "$MENU" | grep -Em1 "$RGX")"

         read -t 0.1 -n 1 -s KEYPRESS
         KEYQUEUE=$KEYQUEUE$KEYPRESS
         if [ ! "$KEYQUEUE" ]; then
            PlaySound "$SOUNDS/$DIGIT.wav"
            if [ "$AUDIO" ]; then
               #echo "SpeakTarget: playing '$KEYAUDIO' then audio file '$AUDIO'"
               PlaySound "$MENU/$AUDIO"
            else
               RGX="^${CODE}${DIGIT}[^0-9]+.*$"
               #AUDIO="$(ls "$MENU" | grep -Em1 "$RGX")"
               #AUDIO="${AUDIO#*_}"
               AUDIO="$(ls "$MENU" | sed -rn "/$RGX/ {s/\.[^.]*//; s/^[^[:alpha:]]+//; s/[^[:alnum:]]+$//; s/[^[:alnum:]]/ /; s/ ( )+/ /; p; q}")"
               #AUDIO="$(echo "$AUDIO" | tr --complement --squeeze-repeats "[:alnum:]" " ")"
               #echo "SpeakTarget: playing '$KEYAUDIO' then converting to speech '$AUDIO'"
               SpeakTTS "$AUDIO"
            fi
         else
            Debug "SpeakTarget early exit: CODE='$CODE' DIGIT='$DIGIT' KEYQUEUE='$KEYQUEUE'"
         fi
         ;;
      *)
         Error "SpeakTarget: invalid: code='$CODE' digit='$DIGIT'"
         ;;
   esac
}

#--------------------------------------------------------------------------
SpeakTargets() {
   local CODE=$1
   #ListTargetCodes $CODE | while read NUM; do
   # CODE might be blank, so quote it:
   [ "$KEYQUEUE" ] || SpeakTarget "$CODE" 0

   local DIGIT=1
   while [ $DIGIT -lt 10 -a ! "$KEYQUEUE" ]; do
      #echo "trying code '$CODE' digit '$DIGIT'"
      #local RGX="^${CODE}${DIGIT}_[^.]+\.(wav|sh)$"
      ls $MENU/${CODE}${DIGIT}_* >/dev/null 2>&1 && \
         SpeakTarget "$CODE" "$DIGIT"
      DIGIT=$((DIGIT + 1))
   done
}

#--------------------------------------------------------------------------
RunTarget() {
   local CODE=$1
   local RGX="^${CODE}[^0-9].*\\.sh"
   Debug "RunTarget: RGX='$RGX'"
   #ls "$MENU"
   #echo "RunTarget: RGX='$RGX'  targets:"
   #ls "$MENU" | grep -Em1 "$RGX"
   local TARGET="$(ls "$MENU" | grep -Em1 "$RGX")"
   if [ ! "$TARGET" ]; then
      Error "RunTarget: no target found with RGX='$RGX'"
   elif [ -x "$MENU/$TARGET" ]; then
      # found a valid target
      Info "RunTarget: running target: $TARGET"
      $MENU/$TARGET
   else
      Error "RunTarget: target is not executable: '$TARGET'"
   fi
}

#--------------------------------------------------------------------------
ParseCommandline() {
   # getopts might have been used in the shell, so reset this to be safe?
   OPTIND=1

   while getopts "h?m:" opt; do

      case "$opt" in
         m) MENU=$OPTARG
            ;;
         *)
            echo "${0##*/}: Help should be here..."
            exit 0
            ;;
      esac
   done

   shift $((OPTIND-1))

   # get rid of the "end of options" separator, if any
   [ "$1" = "--" ] && shift

   [ "$1" ] && {
      echo "ERROR: Unused commandline options: $@"
      exit 1
   }
}

#--------------------------------------------------------------------------
## Function to read a single keypress from the user.
#
ReadKey() {
    STTY_SAVE="$(stty -g 2>/dev/null)"      # save our terminal settings
    stty cbreak -echo 2>/dev/null           # enable independent processing of each input character
    #ONECHAR=$(dd bs=1 count=1 2>/dev/null)  # read one byte from standard in
    ONECHAR="$(head -c1)"                   # read one byte from standard in
    stty $STTY_SAVE 2>/dev/null             # restore the terminal settings
    echo "$ONECHAR"
}

#--------------------------------------------------------------------------
#==========================================================================

ParseCommandline "$@"
CheckSetup
QUIT=""
while [ ! "$QUIT" ]; do

   [ "$KEYQUEUE" ] || {
      SpeakTargets $CODE
   }

   # get the first key in the buffer
   KEY="${KEYQUEUE:0:1}"
   KEYQUEUE="${KEYQUEUE:1}"
   Debug "Main: CODE='$CODE'  KEYQUEUE='$KEYQUEUE'  KEY='$KEY'"
   # if no KEY from buffer, read a key
   [ "$KEY" ] || {
      Debug "Main: no keys buffered - waiting on readkey"
      #ListTargetCodes "$CODE" ""
      KEY="$(ReadKey)"
      Debug "Main: CODE='$CODE'  KEYQUEUE should be empty '$KEYQUEUE'  just read KEY='$KEY'"
   }
   # '0' means go back one menu level.
   # '1' - '9' are possible submenus to go to.
   # 'Q' for Quit.
   # Any other key causes the options to be spoken again.
   case $KEY in
      1|2|3|4|5|6|7|8|9)
         Debug "Main: code is '$CODE' got key $KEY, targets are:"
         #ListTargetCodes "$CODE$KEY"
         TARGETS=$(ListTargetCodes "$CODE$KEY" | wc -l)
         Debug "Main: OldCode: '$CODE'  NewKey: '$KEY'  Targets:'$TARGETS'"
         #echo "---targets---"; ls "$MENU" | grep -E "^$CODE${KEY}_.*"; echo "---"
         case $TARGETS in
            0) Debug "Main: NO DEEPER TARGETS"
               RunTarget $CODE$KEY
               ;;
      #      1) echo "Info: SINGULAR TARGET TO EXECUTE"
      #         RunTarget $CODE$KEY
      #         ;;
            *) Debug "Main: New menu level: "
               CODE=$CODE$KEY;;
         esac
         ;;
      0)
         Debug "Main: OldCode: '$CODE'  NewKey: '$KEYPRESS' = BACK"
         CODE=${CODE%%?}
         ;;
      q|Q)
         Info "Main:  OldCode: '$CODE'  NewKey: '$KEYPRESS' = QUIT"
         QUIT="TRUE"
         ;;
      *) Warning "Main: bad key '$KEY'"
         ;;
   esac
done

