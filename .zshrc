alias gst="git status"
alias gm="git commit -m"
alias gck="git checkout"
alias cdc="cd /Users/alexander.samusev/Documents/Parity/current"
alias gcm="git checkout master || git checkout main"
alias git_cleanup='git branch | grep -v "master\|stable\|main" | xargs git branch -d -f'
alias vssh="vagrant ssh"
alias vdf="vagrant destroy -f"
alias cpb="docker pull paritytech/ci-linux:production && cargoenvclean paritytech/ci-linux:production bash"
#alias docker="podman"

#source <(kubectl completion zsh)
alias k=kubectl
complete -F __start_kubectl k

export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent

function gpb {
  BRANCH=$(git branch --show-current)
  git push origin $BRANCH
}

function gplb {
  BRANCH=$(git branch --show-current)
  git pull origin $BRANCH
}

function gpfb {
  BRANCH=$(git branch --show-current)
  git push -f origin $BRANCH
}

function gfo {
  git fetch origin $1
}

function cargoenv {
  dirname="$(basename $(pwd))"
  user=$(whoami)
  echo "Cargo as a virtual environment in" "$dirname" "dir"
  docker volume inspect cargo-cache > /dev/null || docker volume create cargo-cache
  docker run --rm -it -w /shellhere/"$dirname" \
                    -v "$(pwd)":/shellhere/"$dirname" \
                    -v cargo-cache:/cache/ \
                    -e CARGO_HOME=/cache/cargo/ \
                    -e SCCACHE_DIR=/cache/sccache/ "$@"
}

function cargoenvnr {
  dirname="$(basename $(pwd))"
  user=$(whoami)
  echo "Cargo as a virtual environment in" "$dirname" "dir as nonroot"
  docker volume inspect cargo-cache > /dev/null || docker volume create cargo-cache
  docker run --rm -it -w /shellhere/"$dirname" \
                    -v "$(pwd)":/shellhere/"$dirname" \
                    -v cache-nonroot:/cache/ \
                    -e CARGO_HOME=/cache/cargo/ \
                    -e SCCACHE_DIR=/cache/sccache/ "$@"
}


function cargoenvclean {
  dirname="$(basename $(pwd))"
  user=$(whoami)
  echo "Cargo as a virtual environment in" "$dirname" "dir"
  docker volume inspect cargo-cache > /dev/null || docker volume create cargo-cache
  docker run --rm -it -w /shellhere/"$dirname" \
                    -v "$(pwd)":/shellhere/"$dirname" "$@"
}

function cargocacheclean {
  docker volume rm cargo-cache
  docker volume create cargo-cache
}

function cargocachenrclean {
  docker volume rm cache-nonroot
  docker run --rm -v cache-nonroot:/cache busybox /bin/sh -c 'touch /cache/.initialized && chown -R 1000:1000 /cache'
}

function dex {
  docker run -exec -it $1 bash
}

if [ "$(docker-machine status)" != 'Stopped' ]; then eval $(docker-machine env default); else echo "docker machine stopped"; fi

# tput howto: https://linuxcommand.org/lc3_adv_tput.php
BOLD_ORG_FG=$(tput bold)$(tput setaf 208)
BOLD_ORG_FG_YW=$(tput bold)$(tput setaf 11)
BOLD=$(tput bold)
RESET=$(tput sgr0)

h() {
    printf "\n"
    printf "%s\n" "${BOLD_ORG_FG_YW}Git${RESET}"
    printf "\n"
    printf "%s\n" "${BOLD_ORG_FG}gst${RESET} - git status"
    printf "%s\n" "${BOLD_ORG_FG}gm${RESET} - git commit -m"
    printf "%s\n" "${BOLD_ORG_FG}gck${RESET} - git checkout"
    printf "%s\n" "${BOLD_ORG_FG}git_cleanup${RESET} - clean all branches in current repo apart main/master"
    printf "%s\n" "${BOLD_ORG_FG}gpb${RESET} - pushes origin current branch"
    printf "%s\n" "${BOLD_ORG_FG}gplb${RESET} - git pull origin current branch"
    printf "%s\n" "${BOLD_ORG_FG}gpfb${RESET} - git push --force origin current branch"
    printf "%s\n" "${BOLD_ORG_FG}gfo${RESET} - git fetch origin <branchname>"
    printf "\n"
    printf "%s\n" "${BOLD_ORG_FG_YW}Misc${RESET}"
    printf "\n"
    printf "%s\n" "${BOLD_ORG_FG}cargoenvclean${RESET} - run docker with mounted current folder, usage: cargoenvclean paritytech/ci-linux:production bash"
    printf "%s\n" "${BOLD_ORG_FG}cpb${RESET} - docker pull paritytech/ci-linux:production and run with cargoenvclean"
    printf "%s\n" "${BOLD_ORG_FG}tas${RESET} - tmux attach-session"
    printf "%s\n" "${BOLD_ORG_FG}dex${RESET} - docker run exec bash, usage dex debian:latest bash"

}

# some useful things can be found here: https://github.com/Bhupesh-V/ugit/blob/master/ugit