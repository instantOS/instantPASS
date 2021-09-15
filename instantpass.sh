#!/usr/bin/env bash

# password manager using pass and instantmenu

shopt -s nullglob globstar

selectpassword() {
    printf '%s\n' "${password_files[@]}" | smartcat instantpass | instantmenu -q 'password selection' -l 20 -rc "$0 --menu"
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

if [ "$1" = '--menu' ]; then
    CHOICE="$(
        echo ':g add password
:r delete password
:b close menu' | instantmenu -l 20 -h -1 -rc "$0" -q 'instantPASS menu'
    )"
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

if [ -e "$HOME"/.password-store/"$password".gpg ]; then
    if [ "$(du -s ~/.password-store/"$password".gpg | grep -o '^[0-9]*')" -gt 100 ]; then
        if imenu -c "$password is a large file, would you like to export it to the file system instead of the clipboard?"; then
            SAVEFILE="$(zenity --file-selection --save --confirm-overwrite --filename "$(basename "$password")")"
            [ -z "$SAVEFILE" ] && exit
            pass "$password" >"$SAVEFILE"
            exit
        fi
    fi
fi

if grep -q '\.otp$' <<<"$password"; then
    pass otp -c "$password" 2>/dev/null && imenu -t 'copied one time password to clipboard'
else
    pass show -c "$password" 2>/dev/null && imenu -t 'copied password to clipboard'
fi

smartcat instantpass "$password" 1000 &
