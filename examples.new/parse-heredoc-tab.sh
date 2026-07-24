#!/bin/sh
# heredoc with tabs (<<-) inside a function
func_with_heredoc () {
  cat <<-EOF
	hello
	EOF
}
func_with_heredoc
