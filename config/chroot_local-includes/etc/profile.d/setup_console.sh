# Only run if this is an interactive text bash session
if [ -n "$PS1" ] && [ -n "$BASH_VERSION" ] && [ -z "$DISPLAY" ]; then
   echo "Press enter to activate this console"
   read answer
   # The user should have chosen their preferred keyboard layout
   # in tails-greeter by now.
   . /etc/default/locale
   . /etc/default/keyboard
   sudo setupcon
fi
