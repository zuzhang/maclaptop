#!/bin/sh

# Modify app list as you wish. Better test first with `brew search` or `brew info` before adding new apps.
brew_app=( 'wget' 'caskroom/cask/brew-cask' 'macvim --with-override-system-vim' 'autojump' \
  'tree' 'cmake' 'maven' 'ctags' 'mysql' 'homebrew/nginx/nginx-full' )
# Use `brew cask` series commands
cask_app=( 'google-chrome' 'sogouinput' 'skype' 'slack' 'rescuetime' 'neteasemusic' 'dash' \
  'rubymine7' 'sequel-pro' 'mou' )

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
  brew list -1 | grep -Fqx "$1"
}

brew_is_upgradable() {
  ! brew outdated --quiet "$1" >/dev/null
}

brew_cask_expand_alias() {
  brew cask info "$1" 2>/dev/null | head -1 | awk '{gsub(/:/, ""); print $1}'
}

brew_cask_is_installed() {
  local NAME
  NAME=$(brew_cask_expand_alias "$1")
  brew cask list -1 | grep -Fqx "$NAME"
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
    brew cask install "$@"
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

install_fonts() {
  local font_path="$HOME/Library/Fonts"
  if ! find $font_path -iname '*powerline*' >/dev/null; then
    echo_installing "Powerline Fonts"
    cd ~/Desktop
    git clone https://github.com/powerline/fonts.git
    ./fonts/install.sh
    rm -r fonts
  else
    echo_installed "Powerline Fonts"
  fi
}

install_rvm() {
  if ! command -v rvm >/dev/null; then
    echo_installing 'RVM'
    \curl -sSL https://get.rvm.io | bash -s stable
  else
    echo_installed 'RVM'
  fi
}

config_mysql() {
  fancy_echo "Config MySQL... "
  sudo ln -sfv /usr/local/Cellar/mysql/*/*.plist ~/Library/LaunchAgents
  launchctl load -F ~/Library/LaunchAgents/*mysql*.plist
  mysql -uroot -e \
    "grant all privileges on *.* to '$db_user'@'%' identified by '$db_pass'"
  mysql -uroot -e \
    "grant all privileges on *.* to '$db_user'@'localhost' identified by '$db_pass'"
}

config_nginx() {
  fancy_echo "Config nginx..."
  sudo ln -sfv /usr/local/opt/nginx-full/*.plist ~/Library/LaunchAgents
  launchctl load ~/Library/LaunchAgents/homebrew.mxcl.nginx-full.plist
}

config_ohmyzsh() {
  # replace plugins config
  local zsh_file=~/.zshrc
  local plugins='(git, autojump, ruby)'
  sed -i '' "s/^plugins=.*/plugins=$plugins/g" "$zsh_file"

  source ~/.zshrc
}

config_vim() {
  cd ~
  git init
  git remote add origin https://github.com/zuzhang/zzvimrc4ruby.git
  git fetch origin
  git checkout master
  git merge master origin/master

  mkdir -p ~/.vim/bundle/
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

  echo_installing 'Vim Plugin YouCompleteMe'
  git clone https://github.com/Valloric/YouCompleteMe.git ~/.vim/bundle/YouCompleteMe
  cd ~/.vim/bundle/YouCompleteMe
  git submodule update --init --recursive
  ./install.py

  echo_installing 'Vim Plugins'
  vim +BundleInstall! +BundleClean +qall
}

install_homebrew

# install_ohmyzsh
# TODO add lines
install_brew_app
install_cask_app
install_iterm2_nightly

install_fonts

install_rvm
# TODO install ruby

config_ohmyzsh
# set ssh-key
# config_ssh
config_mysql
# set startup
config_nginx
# config_vim

fancy_echo 'Script Executed Successfully.'
