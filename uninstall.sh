# #!/bin/bash

# # Define installation directory
# INSTALL_DIR="/usr/local/bin"

# # Remove the main script from the installation directory
# rm "$INSTALL_DIR/sets"

# # Remove symbolic links for instances.sh and uninstall.sh from the installation directory
# rm "$INSTALL_DIR/sets-instances.sh"
# rm "$INSTALL_DIR/uninstall-docker.sh"

# echo "Uninstallation complete."


#!/bin/bash

install_dir="$HOME/bin/sets"

# Check if sets CLI is installed
if [ -d "$install_dir" ]; then
  echo "Uninstalling sets CLI..."

  # Remove installation directory
  rm -rf "$install_dir"

  # Remove sets CLI from the PATH in the user's profile
  user_shell=$(basename "$SHELL")

  if [ "$user_shell" = "bash" ]; then
    profile_file="$HOME/.bash_profile"
  elif [ "$user_shell" = "zsh" ]; then
    profile_file="$HOME/.zshrc"
  else
    echo "Unsupported shell: $user_shell. Please manually update your shell profile."
    exit 1
  fi

  sed -i '/export PATH=\$HOME\/bin\/sets:\${PATH}/d' "$profile_file"

  # Remove sudoers configuration for sets
  sudoers_file="/etc/sudoers.d/sets"
  sudo rm -f "$sudoers_file"


  if [ -e "$profile_file" ]; then
    sed -i '/export PATH.*bin\/sets/d' "$profile_file"
    echo "Sets CLI has been uninstalled."
  else
    echo "Warning: Unable to find $profile_file. Please remove the PATH entry manually."
  fi
else
  echo "Sets CLI is not installed on this machine."
fi

