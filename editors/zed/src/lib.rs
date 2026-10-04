use zed_extension_api::{self as zed, LanguageServerId, Result};

/// Starts `mayu lsp` for the opened worktree.
///
/// Zed runs language servers with the worktree root as the working directory.
/// The app's own `bin/mayu` binstub is preferred because it loads the app's
/// bundle; otherwise `bundle exec mayu lsp` is used. Both `mayu lsp` and
/// Bundler search upwards for their config files (mayu.toml, Gemfile), so
/// this works whenever the opened folder is the Mayu app or lies inside it.
///
/// When the app is nested inside the worktree, override the command in the
/// project's `.zed/settings.json`:
///
/// ```json
/// { "lsp": { "mayu": { "binary": {
///   "path": "/abs/path/to/app/bin/mayu",
///   "arguments": ["lsp", "/abs/path/to/app"]
/// } } } }
/// ```
struct MayuExtension;

impl zed::Extension for MayuExtension {
    fn new() -> Self {
        Self
    }

    fn language_server_command(
        &mut self,
        _language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let env = worktree.shell_env();

        if worktree.read_text_file("bin/mayu").is_ok() {
            return Ok(zed::Command {
                command: format!("{}/bin/mayu", worktree.root_path()),
                args: vec!["lsp".into()],
                env,
            });
        }

        let bundle = worktree.which("bundle").ok_or_else(|| {
            "Could not find bin/mayu in the worktree or `bundle` on PATH. \
             Configure lsp.mayu.binary.path in settings."
                .to_string()
        })?;

        Ok(zed::Command {
            command: bundle,
            args: vec!["exec".into(), "mayu".into(), "lsp".into()],
            env,
        })
    }
}

zed::register_extension!(MayuExtension);
