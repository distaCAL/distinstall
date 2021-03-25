#!/bin/bash
set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes ((CAUSES FAIL))
IFS=$'\t\n'

# CONFIG
mysql_lib='mysql-connector-python'
# gsettings set org.gnome.settings-daemon.peripherals.keyboard numlock-state 'on' ERROR: no such key "numlock-state"

# MAIN LOOP
main() {

    # Iterate through command line inputs
    while [ "$1" != "" ]; do
        case $1 in
        -h | --help)
            usage
            exit 0
            ;;
        --target)
            shift
            case $1 in
            alienware)
                # installation for alienware
                ;;
            jetson) 
                # installation for jetsons
                ;;
            other) 
                # installation for other platforms
                ;;
            *) 
                # print error message
                ;;
            esac
            break
            ;;
        -a | --all)
            apt_installation
            zed_sdk_installation
            lambda_stack_installation
            miscelanious_pip_installations
            vino_server_setup
            git_setup
            break
            ;;
        -t | --apt)
            apt_installation
            ;;
        -z | --zed)
            zed_sdk_installation
            ;;
        -l | --lambdastack)
            lambda_stack_installation
            ;;
        -p | --pip)
            miscelanious_pip_installations
            ;;
        -v | --vino)
            vino_server_setup
            ;;
        -g | --git)
            git_setup
            ;;
        *)
            usage
            exit 1
            ;;
        esac
        shift
    done
}

# HELPER FUNCTIONS

function usage() {
    echo "usage: ./installation_script.bash"
    echo "-h | --help"
    echo "-a | --all"
    echo "-t | --apt"
    echo "-z | --zed"
    echo "-l | --lambdastack"
    echo "-p | --pip"
    echo "-v | --vino"
    echo "-g | --git"
    echo "--target"
}

apt_installation() {
    sudo apt update && sudo apt --yes upgrade
    sudo apt install --yes git gitg python3-pip v4l-utils nano ssh
    if sudo apt install meld
    then
        git config --global diff.tool meld
        git config --global merge.tool meld
    fi
}

zed_sdk_installation() {
    sdk_url=""

    case $(uname -r) in
    *-tegra) sdk_url="https://download.stereolabs.com/zedsdk/3.4/jp45/jetsons" ;; # version 3.4.1, jetson, cuda 10.2
    *) sdk_url="https://download.stereolabs.com/zedsdk/3.4/cu111/ubuntu20" ;;     # version 3.4.0, ubuntu 20, cuda 11.1
    esac

    (
        wget -O zedsdk.run "${sdk_url}" &&
            chmod +x zedsdk.run &&
            sh zedsdk.run --accept -- silent
        # rebooted here during manual installation // also discovered zed does NOT install torch and the likes
    )
}

lambda_stack_installation() {
    case $(uname -r) in
    *-tegra) ;;
    *)
        LAMBDA_REPO=$(mktemp) &&
            wget -O "${LAMBDA_REPO}" "https://lambdalabs.com/static/misc/lambda-stack-repo.deb" &&
            sudo dpkg -i "${LAMBDA_REPO}" && rm --recursive --force "${LAMBDA_REPO}" &&
            sudo apt-get update && sudo apt --yes upgrade &&
            echo "cudnn cudnn/license_preseed select ACCEPT" | sudo debconf-set-selections &&
            sudo apt-get install --yes lambda-stack-cuda
        ;;
    esac
}

miscelanious_pip_installations() {
    # those are the necessary installations for our python environment
    pip3 install pyopengl webcolors zmq nanocamera serial opencv-contrib-python==4.2.0.34 # torch torchvision numpy scipy matplotlib cython should already be there
    case $(uname -r) in
    *-tegra) sudo -H pip3 install -U jetson-stats ;; # merci Julien
    *) ;;
    esac
    pip3 install ${mysql_lib}
}

vino_server_setup() {
    gsettings set org.gnome.Vino notify-on-connect false
    gsettings set org.gnome.Vino prompt-enabled false
    gsettings set org.gnome.desktop.notifications show-in-lock-screen false
    gsettings set org.gnome.desktop.notifications show-banners false
    gsettings set org.gnome.desktop.notifications view-only false

    dbus-launch gsettings set org.gnome.Vino require-encryption false
    dbus-launch gsettings set org.gnome.Vino authentication-methods "['vnc']"
    dbus-launch gsettings set org.gnome.Vino vnc-password $(echo -n "12345678" | base64) # password is 12345678. is hard coded for now

    # (crontab -l echo "@reboot /usr/lib/vino/vino-server" 2>/dev/null) | crontab - # shouldve worked, but doesnt. (vino doesnt start)
    cat vino.desktop >~/.config/autostart/vino.desktop
}

git_setup() {
    cp ssh_keys/id_ed25519 ~/.ssh/id_ed25519
    cp ssh_keys/id_ed25519.pub ~/.ssh/id_ed25519.pub

    chmod 400 ~/.ssh/id_ed25519

    ssh-add ~/.ssh/id_ed25519

    ssh -o StrictHostKeyChecking=accept-new github.com

    git clone git@github.com:doorjuice/dista.git
}

# CALL SITE
main "${@}"
