// SPDX-License-Identifier: GPL-2.0-only

//! `stg redo` implementation.

use anyhow::Result;
use clap::Arg;

use crate::color::get_color_stdout;
use crate::stack::Stack;

use super::undo::find_undo_state;
use super::StGitCommand;

pub(super) fn get_command() -> (&'static str, StGitCommand) {
    (
        "redo",
        StGitCommand {
            make,
            run,
            category: super::CommandCategory::StackManipulation,
        },
    )
}

fn make() -> clap::Command<'static> {
    clap::Command::new("redo")
        .about("Undo the last undo operation")
        .long_about(
            "If the last command was an undo, the patch stack state will be reset to its state \
             before the undo. Consecutive redos will undo the effects of consecutive invocations \
             of \"stg undo\".\n\
             \n\
             It is an error to redo if the last stack-modifying command was not an undo.",
        )
        .arg(
            Arg::new("number")
                .long("number")
                .short('n')
                .help("Undo the last <n> undos")
                .value_name("n")
                .value_parser(|s: &str| {
                    s.parse::<isize>()
                        .map_err(|_| format!("'{s}' is not an integer"))
                        .and_then(|n| {
                            if n >= 1 {
                                Ok(n)
                            } else {
                                Err("Bad number of commands to redo".to_string())
                            }
                        })
                }),
        )
        .arg(
            Arg::new("hard")
                .long("hard")
                .help("Discard changes in the index and worktree"),
        )
}

fn run(matches: &clap::ArgMatches) -> Result<()> {
    let repo = git2::Repository::open_from_env()?;
    let stack = Stack::from_branch(&repo, None)?;
    let redo_steps = matches.get_one::<isize>("number").copied().unwrap_or(1);

    stack
        .setup_transaction()
        .use_index_and_worktree(true)
        .allow_bad_head(true)
        .discard_changes(matches.contains_id("hard"))
        .with_output_stream(get_color_stdout(matches))
        .transact(|trans| {
            let redo_state = find_undo_state(trans.stack(), -redo_steps)?;
            trans.reset_to_state(redo_state)
        })
        .execute(&format!("redo {redo_steps}"))?;

    Ok(())
}
