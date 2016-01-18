EmacsUtils
==========

Handy Emacs utilities

I've been using Gnu Emacs since it was publicly available (1985?), and have contributed some packages which are included with Emacs, notably the [Allout outliner](http://myriadicity.net/software-and-systems/craft/emacs-allout), [icomplete mode](http://www.emacswiki.org/emacs/IcompleteMode), and python-mode's [pdbtrack functionality](http://myriadicity.net/software-and-systems/craft/crafty-hacks#section-1). Like many long-time Emacs users, I have a bunch of custom code, some that's crucial. Here are some that others might find useful. I hope to include more, as time allows.

* **[multishell.el](./multishell.el)**

Manage interaction with multiple local and remote shell buffers - now in its own repository: https://github.com/kenmanheimer/EmacsMultishell (to ease ELPA maintenance).

* **[xsel.el](./xsel.el)**

  X copy and paste emacs region from emacs tty sessions, using a shell command.

  If xsel or linux or cygwin equivalent is installed, and DISPLAY is
  working, use `klm:xsel-copy` to copy the region to the X clipboard and
  `klm:xsel-paste` to paste the contents of the clipboard at point.

  One benefit is that `klm:xsel-paste` pastes are single units, rather than
  a sequence of individual keystrokes that constitute regular X pastes to a
  terminal. This avoids layers of parsing, indenting, auto-paren insertion,
  and so forth. (You can always do a regular X paste on occasions when you
  want that processing.)

  NOTE well - ssh has has a little known, severe default X11 forwarding
  timeout that leads to unexpected failures after ten minutes - yikes! To
  mitigate it, set ForwardX11Timeout to something larger - up to the
  unexpected max of 596h, slightly beyond which the number is ignored. See
  http://b.kl3in.com/2012/01/x11-display-forwarding-fails-after-some-time/
  for details.

* **[pdbtrack.el](./pdbtrack.el)**

  [I've moved my standalone version of pdbtrack aside. I hadn't realized 
  that the version that I derived this code from lacks my source-buffer 
  fallback provisions. It looks like I'm going to have to do some
  unraveling to reconstruct the best basis.]

  Add sensitivity to comint shells so the source file lines are automatically
  presented in a separate window when the Python PDB debugger steps to them.

  This is derived from the pdb tracking code, which I originally wrote, and
  which has been included in (various) official Emacs Python modes. I wanted
  a version that I could more easily tweak and maintain, independently of
  the python-mode code.

  It would be nice to eventually generalize this code, to work for things
  like the node.js debugger. We'll see if I (or anyone) ever gets around to
  that.
