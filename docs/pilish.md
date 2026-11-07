# Pilish

The personal configuration installs [Pilish](https://github.com/dnouri/pilish#quick-start)
on Emacs 29.1 or later with tree-sitter support. It loads the frontend when
`M-x pilish` (or the shorter `M-x pi`) is invoked. Older Emacs builds skip this
integration. The existing preload configuration supplies both MELPA and GNU
ELPA, which are needed to resolve Pilish and its dependencies.

When the integration is active, Prelude checks for the `pi` executable and
runs `npm install -g @earendil-works/pi-coding-agent` when it is missing.
If npm is unavailable or the installation fails, Prelude reports a warning
instead of aborting startup; you can then install the CLI manually.

Before starting a session:

1. Install Node.js 22.19 or later, which provides npm. Prelude will install
   the Pi CLI automatically when `pi` is missing. To install or upgrade it
   manually, run:

   ```sh
   npm install -g @earendil-works/pi-coding-agent
   ```

2. Run `pi` in a terminal and use `/login` to authenticate, or configure a
   provider API key as described in the upstream quick start. Pilish reuses
   Pi's credentials; interactive `/login` must be done in the terminal.
3. Ensure the `pi` executable is on Emacs's `exec-path` (check with
   `M-: (executable-find "pi")`). If it was just installed, restart Emacs or
   add npm's global binary directory to `PATH` when necessary.
4. Restart Prelude, visit a project, and run `M-x pilish`. On first use,
   accept the Markdown tree-sitter grammar installation prompt. A C compiler
   such as `gcc` or `cc` is needed to build missing grammars.

Write a prompt in the input window and press `C-c C-c` to send it.
CLI installation is attempted automatically when `pi` is missing.
Authentication and grammar compilation remain manual setup steps; loading
the personal configuration does not start a Pi session.
Pilish uses upstream defaults, including approving project-local Pi resources
at session startup. See upstream's `pilish-project-trust-policy` documentation
if you prefer to use Pi's saved trust decisions.
