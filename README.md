![alt text](./colors/.n0kovim.png)
Neovim Configuration


There have been many iterations and different machines that I've worked on. This is the most recent iteration, clean history.


_Installation:_
1. Ensure that you have neovim installed. Most likely this is in your distribution's package manager. Or you can compile from source 'git clone https://github.com/neovim/neovim'. `cd` into neovim, and `sudo make install` (some features might require you to be on the nightly build, use git tags to find it and then compile).
2. Chicken/egg situation. Navigate to the `options.lua` file, and comment out `tokyonight` colorscheme. (It will be installaed with you update the build with packer.)
3. Navigate to the `plugins.lua` file, and save it (this will pull all of the plugins I reference). 
4. You can go back and uncomment `tokyonight` from the `options.lua` file, as the colorshceme is now installed. 

Navigate around. `Which-key` plugin will show you a few of the keybindings (activated with you press the leader key `space`, but not all of them. You can find those in the `keymaps.lua` file.)
