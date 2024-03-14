# #!/bin/bash

# # Define installation directory
# INSTALL_DIR="/usr/local/bin"

# # Copy the main script to the installation directory
# cp sets "$INSTALL_DIR"

# # Create symbolic links for instances.sh and uninstall.sh in the installation directory
# ln -s "$(pwd)/lib/sets-instances.sh" "$INSTALL_DIR/sets-instances.sh"
# ln -s "$(pwd)/lib/uninstall-docker.sh" "$INSTALL_DIR/uninstall-docker.sh"

# echo "Installation complete. You can now use sets cli to manage instances."


#!/bin/bash

script_pwd=$(pwd)
install_dir="$HOME/bin/sets"

echo $install_dir

# Detect the user's default shell
user_shell=$(basename "$SHELL")

# Check if sets CLI is already installed
if [ -d "$install_dir" ]; then
  echo "Sets CLI is already installed on this machine."
else
  # Create installation directory and navigate to it
  mkdir -p "$install_dir" && cd "$install_dir"

  # Copy necessary files to the installation directory
  echo "Installing sets CLI"
  mkdir -p lib
  cp -r "$script_pwd/lib/"* ./lib
  cp "$script_pwd/sets" .

  # Add sets CLI to the PATH in the user's profile for the detected shell
  echo "Adding sets CLI to $user_shell commands"
  profile_file=""
  if [ "$user_shell" = "bash" ]; then
    profile_file="$HOME/.bash_profile"
  elif [ "$user_shell" = "zsh" ]; then
    profile_file="$HOME/.zshrc"
  else
    echo "Unsupported shell: $user_shell. Please manually update your shell profile."
    exit 1
  fi

  current_profile=$(grep -E '^export PATH=.*bin/sets' "$profile_file")

  if [ -z "$current_profile" ]; then
    echo 'export PATH=$HOME/bin/sets:${PATH}' >> "$profile_file"
  fi

  sudoers_file="/etc/sudoers.d/sets"
  echo "Defaults secure_path=\"$install_dir:\${secure_path}\"" | sudo tee "$sudoers_file" > /dev/null
  
  echo "Installation complete. You can now use sets CLI to manage instances."
fi


