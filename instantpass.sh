#!/usr/bin/env bash

# password manager using pass and instantmenu

shopt -s nullglob globstar

if [ "$1" = "--fzf" ]; then
    USEFZF=1
    shift
fi

choicemenu() {
    if [ -n "$USEFZF" ]; then
        # TODO: add frecency
        fzf
    else
        instantmenu -q 'password selection' -l 20 -rc "$0 --menu"
    fi
}

selectpassword() {
    printf '%s\n' "${password_files[@]}" | smartcat instantpass | choicemenu
}

prefix=${PASSWORD_STORE_DIR-~/.password-store}

if ! [ -e "$prefix" ]; then
    notify-send 'no password store found, please run pass init in a terminal'
    exit 1
fi

password_files=("$prefix"/**/*.gpg)
password_files=("${password_files[@]#"$prefix"/}")
password_files=("${password_files[@]%.gpg}")

insertpw() {
    if [ -z "$1" ]; then
        PWNAME="$(imenu -i 'insert password' 'password name')"
        [ -z "$PWNAME" ] && return 1
    else
        PWNAME="$1"
    fi

    PWCONTENT="$(imenu -P 'leave empty to generate random password' || echo 'quitplease')"
    [ "$PWCONTENT" = "quitplease" ] && return 1

    if [ -z "$PWCONTENT" ]; then
        pass generate "$PWNAME" 15
        notify-send "generated 15 character password for $PWNAME"
        return
    else
        CHECKPW="$(imenu -P 'confirm password' || echo 'quitplease')"
        [ "$CHECKPW" = "quitplease" ] && return 1
        if ! [ "$CHECKPW" = "$PWCONTENT" ]; then
            imenu -e 'passwords do not match'
            unset PWCONTENT
            unset CHECKPW
            insertpw "$PWNAME"
            return
        else
            if grep -q 'otpauth://' <<<"$PWCONTENT"; then
                notify-send 'created otp password'
                {
                    echo "$PWCONTENT"
                    echo "$PWCONTENT"
                } | pass otp insert "$PWNAME.otp"
            else
                {
                    echo "$PWCONTENT"
                    echo "$PWCONTENT"
                } | pass insert "$PWNAME"
            fi
            return
        fi

    fi
}

cleanpasswords() {
    refreshpasswords
    echo 'cleaning cache from removed password'
    printf '%s\n' "${password_files[@]}" | smartcat --clean instantpass
}

refreshpasswords() {
    password_files=("$prefix"/**/*.gpg)
    password_files=("${password_files[@]#"$prefix"/}")
    password_files=("${password_files[@]%.gpg}")
}

deletepw() {
    DELETEPASS="$(selectpassword)"
    [ -z "$DELETEPASS" ] && return 1
    cleanpasswords
    pass rm "$DELETEPASS" || {
        imenu -e 'failed to delete password'
        return 1
    }
    cleanpasswords
}

echousage() {

    cat <<EOF
Usage: instantpass [--menu|--help]
    --menu
        open context menu to insert or delete a password
    --help
        bring up this message
EOF

}

if [ "$1" = '--help' ]; then
    echousage
    exit
fi

if [ "$1" = '--menu' ]; then
    if [ -n "$USEFZF" ]; then
        CHOICE="$(
            echo 'add password
delete password
close menu' | fzf
        )"
    else
        CHOICE="$(
            echo ':g add password
:r delete password
:b close menu' | instantmenu -l 20 -h -1 -rc "$0" -q 'instantPASS menu'
        )"
    fi
    echo choice "$CHOICE"
    [ -z "$CHOICE" ] && exit
    case "$CHOICE" in
    *delete*)
        deletepw
        ;;
    *add*)
        insertpw
        ;;
    *)
        exit
        ;;
    esac

    # insertpw
    exit
fi

password="$(selectpassword)"

[[ -n $password ]] || exit

notifier() {
    if [ -n "$USEFZF" ]; then
        echo "$1"
    else
        if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
            notify-send "$1"
        else
            imenu -t "$1"
        fi
    fi
}

if [ -e "$HOME"/.password-store/"$password".gpg ]; then
    if [ "$(du -s ~/.password-store/"$password".gpg | grep -o '^[0-9]*')" -gt 100 ] || grep -q '\.file$' <<<"$password"; then
        if imenu -c "$password is a large file, would you like to export it to the file system instead of the clipboard?"; then
            # TODO: add TUI alternative for zenity
            SAVEFILE="$(zenity --file-selection --save --confirm-overwrite --filename "$(basename "$password")")"
            [ -z "$SAVEFILE" ] && exit
            pass "$password" >"$SAVEFILE"
            exit
        fi
    fi
fi

if grep -q '\.otp$' <<<"$password"; then
    pass otp -c "$password" 2>/dev/null && notifier 'copied one time password to clipboard'
else
    pass show -c "$password" 2>/dev/null && notifier 'copied password to clipboard'
fi

smartcat instantpass "$password" 1000 &
