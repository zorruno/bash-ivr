# bash-ivr
Interactive Voice Response system (IVR) in bash - speaks a menu then uses digit keys to select options.

The menu system is defined by a set of suitably named files in a defined directory.

Custom wav files can be used to speak each menu option, or they can use TTS.

## Dependencies
  - flite - Text To Speech (TTS) - https://packages.debian.org/jessie/flite
  - play - plays wav files - I'm probably using the one from sox - https://packages.debian.org/jessie/sox
  
## Other things you'll need
  - a set of wav files, one for each digit to be spoken (eg. 1.wav)
  - a sound to mark the start of a menu (menuheader.wav)
