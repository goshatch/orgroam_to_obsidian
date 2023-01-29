# Convert org-roam files to Obsidian-ready markdown

This is a Ruby script that help converting a collection of notes created with [org-roam](https://www.orgroam.com/) to a bunch of Markdown files suitable for being imported into an [Obsidian](https://obsidian.md) vault.

I hacked this together in a couple of evenings because I wanted to see if it made sense to start using Obsidian instead of Emacs for my note library.

## Requirements

- [Pandoc](https://pandoc.org/)
- Ruby and bundler

## Running the conversion

```sh
$ git clone https://github.com/goshatch/orgroam_to_obsidian
$ cd orgroam_to_obsidian
$ cp ~/.emacs.d/.local/cache/org-roam.db input/
$ cp -R ~/org/roam input/
$ bundle install
$ ./convert.rb
```

The locations of `org-roam.db` and the `roam` directory above are provided as examples only. You can find the actual locations on your system by inspecting these variables in Emacs:

- `org-roam-db-location`
- `org-roam-directory`

Make sure to COPY these to your `input` directory, so that you have a backup in case things go wrong.

After running `convert.rb`, the generated markdown files will be under the `output` directory.

## Help and contributing

If you need any help with this, please feel free to reach out to me [on Mastodon](https://merveilles.town/@gosha), or to submit an issue to the repository.

Pull requests with improvements are very welcome.
