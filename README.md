
# Vim-Operator-Insert-Append
This Vim plugin provides operators for inserting and appending before/after a `{motion}`/`{textobject}`.

# Why?
Tired of typing `ea` and then being very sad when you realize that (in contrast to `I` and `A`) you cannot repeat `ea` with `.`?\
This sadness ends today!\
Instead of `ea`, type `<Leader>aiw` and you can repeat the insertion at the end of the current word with the `.` command.\
Insert the last text at the end of the current word twice? `2.` just works!

# Guide
## Mappings
No mappings are created automatically. Add your own. I use:
```
nmap <M-i> <Plug>(OperatorInsert-first-invocation)
nmap <M-a> <Plug>(OperatorAppend-first-invocation)
```
Alternatively, you could use `<Leader>i` or override the built-in `I` and `A` commands.\
They can then be simulated with `Iil` and `Aal`, where `il` and `al` are custom line text-objects.

## Usage
Type `[count]<Leader>i{motion}` to start insert mode at the beginning of the text selected by `{motion}`. When leaving insert mode (with Escape, not with CTRL-C), the inserted text is duplicated by `[count]`, as with the normal `i` command.
Upon the first repeat with `.`, you have to enter the `{motion}` again. (See section `Limitations`.)
For subsequent repetitions, the motion is reused. This is a typical workflow:
* On the first word, type `<Leader>aiwSomeText<Esc>`
* On the second word, type `.iw`
* On the third and all subsequent words, type `.`
* If you occasionally want to append the text 2 times, type `2.`

Analogously, `<Leader>a{motion}` starts insert mode at the end of the selected text.

The settings `g:OperatorInsert_reuse_count_on_repeat` and `g:OperatorAppend_reuse_count_on_repeat` determine if
`.` uses the count from the last invocation.\
If disabled, `.` uses count `1`.\
You can always give the count explicitly, e.g. use `1.` to override a higher count given on the first invocation.

## Behaviour on linewise motions
If `g:OperatorInsertAppend_linewise_motions_select_whole_lines` is enabled (default 1), then linewise operators such as `j` select whole lines.\
Otherwise, the `'[` and `']` marks determine the selection.
There is usually no good reason to change this setting.

# Requirements
Requires [vim-repeat](https://github.com/tpope/vim-repeat).\
Developed and tested on Neovim 0.4.3. When I tested it on Vim 8.2, it worked, too.

# Limitations
* Typing `5i<BS><Esc>` removes 5 characters, but `5<Leader>aiw<BS><Esc>` removes only 1 character. Repetitions of `i<BS><Esc>` don't work at all.
This will not be changed, since this is a side effect of a workaround for a previous bug, where typing `5<Leader>aiw<Esc>` would insert 5 times the *previous* insert.
* On the first repeat, the `{motion}` is lost and has to be re-entered. This is annoying, but with the current state of Vim's API, this is as good as it gets. If you are interested in the technical details, follow the links in the next section.
* Visual mode is not supported, since it would be useless for those operators.

# Credits / Related Plugins
Rudimentary implementations of this concept have existed for a long time:
* [vim-operator-insert by mwgkgk](https://github.com/mwgkgk/vim-operator-insert)
* [vim-operator-append by mwgkgk](https://github.com/mwgkgk/vim-operator-append)
* [vim-operator-insert by deris](https://github.com/deris/vim-operator-insert)

But the operators were not repeatable, since Vim's plugin API is too limited.\
[In this thread on vi.stackexchange.com](https://vi.stackexchange.com/questions/21593/making-operator-insert-and-append-repeatable), user [Blasco](https://vi.stackexchange.com/users/15345/blasco?tab=profile) describes a creative approach to make those operators repeatable.\
This plugin is based on this suggestion.\
It also adds useful handling of counts and employs some wacky convoluted autocommand hacks to get all the edge cases right.

# License
The Vim licence applies. See `:help license`.
