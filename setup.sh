#! /bin/bash

if [ $# = 0 ]; then
	CMD="all"
else
	CMD=$1
fi

if [[ $EUID -ne 0 ]]; then
	echo "Must be run as root"
	exit 1
fi

# UI tweaks
function run-in-user-session() {
    _display_id=":$(find /tmp/.X11-unix/* | sed 's#/tmp/.X11-unix/X##' | head -n 1)"
    _username=$(who | grep "\(${_display_id}\)" | awk '{print $1}')
    _user_id=$(id -u "$_username")
    _environment=("DISPLAY=$_display_id" "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$_user_id/bus")
    sudo -Hu "$_username" env "${_environment[@]}" "$@"
}
if [[ $CMD = "all" ]] || [[ $CMD = "gsettings" ]]; then
	run-in-user-session gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'suspend'
	run-in-user-session gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 24
	run-in-user-session gsettings set org.gnome.desktop.interface text-scaling-factor 0.9
	run-in-user-session gsettings set org.gnome.desktop.sound event-sounds false
	run-in-user-session gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Super>Tab']"
	run-in-user-session gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "['<Shift><Super>Tab']"
	run-in-user-session gsettings set org.gnome.desktop.wm.keybindings switch-windows "['<Alt>Tab']"
	run-in-user-session gsettings set org.gnome.desktop.wm.keybindings switch-windows-backward "['<Shift><Alt>Tab']"
	run-in-user-session gsettings set org.gnome.shell favorite-apps "['google-chrome.desktop', 'org.gnome.Terminal.desktop', 'intellij-idea-ultimate.desktop', 'steam.desktop', 'enpass.desktop']"
	run-in-user-session gsettings set org.gnome.desktop.interface clock-show-date true
	run-in-user-session gsettings set org.gnome.desktop.interface show-battery-percentage true
fi


# Don't suspend on lid close
if [[ $CMD = "all" ]] || [[ $CMD = "lid" ]]; then
	sed -i '/^HandleLidSwitch=/d' /etc/systemd/logind.conf
	echo HandleLidSwitch=ignore >> /etc/systemd/logind.conf
fi

# Needful things
if [[ $CMD = "all" ]] || [[ $CMD = "base" ]]; then
	apt-get update && apt-get upgrade -y
	apt-get install -y laptop-mode-tools mc git gparted chrome-gnome-shell gnome-tweaks dconf-editor curl steam-installer vlc sl kazam
fi

# Chrome
if [[ $CMD = "all" ]] || [[ $CMD = "chrome" ]]; then
	wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
	echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' | tee /etc/apt/sources.list.d/google-chrome.list
	apt-get update 
	apt-get install google-chrome-stable
fi

# IntelliJ
if [[ $CMD = "all" ]] || [[ $CMD = "intellij" ]]; then
	add-apt-repository -y ppa:mmk2410/intellij-idea
	apt-get install -y intellij-idea-ultimate
fi

# nvidia drivers
if [[ $CMD = "all" ]] || [[ $CMD = "nvidia" ]]; then
	add-apt-repository -y ppa:graphics-drivers
	apt-get install -y nvidia-driver-430 
fi

# Enpass
if [[ $CMD = "all" ]] || [[ $CMD = "enpass" ]]; then
	echo "deb https://apt.enpass.io/ stable main" > /etc/apt/sources.list.d/enpass.list
	wget -O - https://apt.enpass.io/keys/enpass-linux.key | apt-key add -
	apt-get update
	apt-get install -y enpass
fi

# Tuxedo keyboard
if [[ $CMD = "all" ]] || [[ $CMD = "keyboard" ]]; then
	sed '/tuxedo_keyboard/d' /etc/modules
	dkms remove -m tuxedo_keyboard -v 1 --all
	rm -rf /usr/src/tuxedo_keyboard-1
	git clone https://github.com/tuxedocomputers/tuxedo-keyboard.git /usr/src/tuxedo_keyboard-1
	dkms add -m tuxedo_keyboard -v 1
	dkms build -m tuxedo_keyboard -v 1
	dkms install -m tuxedo_keyboard -v 1
	modprobe tuxedo_keyboard
	echo tuxedo_keyboard >> /etc/modules
fi

# Docker
if [[ $CMD = "all" ]] || [[ $CMD = "docker" ]]; then
	apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	apt-get update
	apt-get install -y docker-ce docker-ce-cli containerd.io
	usermod -a -G docker $SUDO_USER
fi
