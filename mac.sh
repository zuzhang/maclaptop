#!/bin/zsh

# Modify app list as you wish. Better test first with `brew search` or `brew info` before adding new apps.
brew_app=( 'wget' 'autojump' 'exa' 'cmake' 'mysql@5.7' )
# Use `brew --cask` series commands
cask_app=( 'google-chrome' 'slack' 'neteasemusic' \
  'intellij-idea' 'tableplus' 'postman' 'keepingyouawake' 'font-hack-nerd-font' 'alfred' )

# Set DB localhost user and password
db_user='root'
db_pass='root'

fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt\n" "$@"
}

echo_installed() {
  fancy_echo "$1 is already installed. Skipping..."
}

echo_installing() {
  fancy_echo "Installing $1..."
}

append_to_file() {
  local file="$1"
  local text="$2"

  if ! grep -qs "^$text$" "$file"; then
    printf "\n%s\n" "$text" >> "$file"
  fi
}

brew_install_or_upgrade() {
  if brew_is_installed "$1"; then
    if brew_is_upgradable "$1"; then
      fancy_echo "Upgrading %s ..." "$1"
      brew upgrade "$@"
    else
      fancy_echo "Already using the latest version of %s. Skipping ..." "$1"
    fi
  else
    fancy_echo "Installing %s ..." "$1"
    brew install "$@"
  fi
}

brew_is_installed() {
  brew list --formula -1 | grep -Fx "$1" >/dev/null
}

brew_is_upgradable() {
  ! brew outdated --formula --quiet "$1" >/dev/null
}

brew_cask_expand_alias() {
  brew info --cask "$1" 2>/dev/null | head -1 | awk '{gsub(/:/, ""); print $1}'
}

brew_cask_is_installed() {
  local NAME
  NAME=$(brew_cask_expand_alias "$1")
  brew list --cask -1 | grep -Fx "$NAME"
}

app_is_installed() {
  local app_name
  app_name=$(echo "$1" | cut -d'-' -f1)
  find /Applications -iname "$app_name*" -maxdepth 1 | egrep '.*' > /dev/null
}

brew_cask_install() {
  if app_is_installed "$1" || brew_cask_is_installed "$1"; then
    echo_installed "$1"
  else
    echo_installing "$1"
    brew install --cask "$@"
  fi
}

install_homebrew() {
  if ! command -v brew >/dev/null; then
    echo_installing 'Homebrew'
      \curl -fsSL \
        'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby
  else
    echo_installed 'Homebrew'
  fi

  # fancy_echo "Updating Homebrew formulas ..."
  # brew update
}

install_ohmyzsh() {
  if ! echo $ZSH | grep -qs oh-my-zsh; then
    echo_installing 'Oh-My-ZSH'
    sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
  else
    echo_installed 'Oh-My-ZSH'
  fi
}

install_brew_app() {
  for app in "${brew_app[@]}"
  do
    brew_install_or_upgrade $app
  done
}

install_cask_app() {
  for app in "${cask_app[@]}"
  do
    brew_cask_install $app
  done
}

install_iterm2_nightly() {
  local iterm='iTerm'
  if app_is_installed "$iterm"; then
    echo_installed "$iterm"
  else
    echo_installing "$iterm"
    cd ~/Desktop
    wget https://iterm2.com/nightly/latest
    unzip latest
    mv iTerm.app /Applications
    rm -r latest
    rm latest
  fi
}

config_mysql() {
  homebrew_cellar='/usr/local/Cellar'
  if [[ $(uname -m) == 'arm64' ]]; then # Mac chip
    homebrew_cellar='/opt/homebrew/Cellar'
  fi

  fancy_echo "Config MySQL..."
  ln -sfv $homebrew_cellar/mysql@5.7/*/*.plist ~/Library/LaunchAgents
  launchctl load -F ~/Library/LaunchAgents/*mysql*.plist
  mysql -uroot -e \
    "grant all privileges on *.* to '$db_user'@'%' identified by '$db_pass'"
  mysql -uroot -e \
    "grant all privileges on *.* to '$db_user'@'localhost' identified by '$db_pass'"
}

config_ohmyzsh() {
  fancy_echo "Config Oh-My-ZSH..."
  # replace plugins config
  local zsh_file=~/.zshrc

  autosuggestionsDir=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  if [ ! -d "$autosuggestionsDir" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$autosuggestionsDir"
  fi
  local plugins='(git autojump zsh-autosuggestions)'
  sed -i '' "s/^plugins=.*/plugins=$plugins/g" "$zsh_file"

  powerlevel10kDir=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
  if [ ! -d "$powerlevel10kDir" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$powerlevel10kDir"
  fi
  # ZSH_THEME="powerlevel10k/powerlevel10k"
  sed -i '' "s/^ZSH_THEME=.*/ZSH_THEME=powerlevel10k\/powerlevel10k/g" "$zsh_file"

  source ~/.zshrc

  fancy_echo "Config Oh-My-ZSH DONE"
}

config_vim() {
  cd ~
  git init
  git remote add origin https://github.com/zuzhang/zzvimrc4ruby.git
  git fetch origin
  git checkout master
  git merge master origin/master

  DIRECTORY=~/.vim/bundle/Vundle.vim
  if [[ ! -d "$DIRECTORY" ]]; then
    git clone https://github.com/VundleVim/Vundle.vim.git "$DIRECTORY"
  else
    cd "$DIRECTORY"
    git pull
  fi

  echo_installing 'Vim Plugins'
  vim +BundleInstall! +BundleClean +qall
}

config_global() {
  # Disable automatic periods with a double space:
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

  # Disable smart quotes as they’re annoying when typing code.
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
}

install_homebrew

install_ohmyzsh
install_brew_app
install_cask_app
install_iterm2_nightly

config_ohmyzsh
# set ssh-key
# config_ssh
config_mysql
## set startup
config_vim
#
config_global

fancy_echo 'Script Executed Successfully.'
