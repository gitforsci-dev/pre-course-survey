# One full test response, for database mode -------------------------------
#
# The click-through test (tests/clickthrough.R) is tuned to preview mode:
# its "Next is refused" checks wait two seconds, which a database write can
# exceed. This script only walks the happy path with long waits, so that a
# first run in database mode creates the table and its columns, and a live
# check on Connect Cloud leaves exactly one test row.
#
# Start the app in database mode first (survey.qmd: mode: database), then:
#   Rscript tests/smoke_database.R [url] [email]
# Default url http://127.0.0.1:8765, default email test@example.org (dropped
# by the admin scripts on pull). Delete the row in Supabase afterwards.

library(chromote)

args  <- commandArgs(TRUE)
url   <- if (length(args) >= 1 && !is.na(args[1])) args[1] else "http://127.0.0.1:8765"
email <- if (length(args) >= 2 && !is.na(args[2])) args[2] else "test@example.org"

b <- ChromoteSession$new()
js <- function(x) b$Runtime$evaluate(x, returnByValue = TRUE)$result$value
visible <- function(sel) isTRUE(js(sprintf(
  "(function(){var e=document.querySelector('%s');return !!(e && e.offsetParent!==null);})()", sel)))
wait_for <- function(sel, timeout = 60) {
  t0 <- Sys.time()
  while (difftime(Sys.time(), t0, units = "secs") < timeout) {
    if (visible(sel)) return(TRUE)
    Sys.sleep(0.5)
  }
  FALSE
}
set_text <- function(id, value) {
  js(sprintf("$('#%s').val(%s).trigger('input').trigger('change');", id, jsonlite::toJSON(value, auto_unbox = TRUE)))
  Sys.sleep(0.6)
}
pick <- function(name, value) {
  js(sprintf("document.querySelector('input[name=\"%s\"][value=\"%s\"]').click();", name, value))
  Sys.sleep(0.6)
}
step <- function(page, next_sel) {
  js(sprintf("document.getElementById('%s_next').click();", page))
  ok <- wait_for(next_sel, 60)
  cat(if (ok) "ok   " else "FAIL ", page, " -> next\n", sep = "")
  if (!ok) { b$close(); quit(status = 1) }
}

invisible(b$Page$navigate(url))
if (!wait_for("#start_next", 90)) { cat("FAIL start page\n"); b$close(); quit(status = 1) }
cat("ok   start page\n")
step("start", "#agreement_next")
pick("consent", "yes")
step("agreement", "#about_next")
set_text("email", email)
pick("github_account", "yes")
set_text("github_username", "octocat")
pick("os", "macos")
pick("install_rights", "yes")
pick("role", "data_steward")
pick("teaches_git", "plan")
step("about", "#rdm_next")
pick("rdm_level", "group")
pick("rdm_activities", "training")
pick("rdm_activities", "publishing")
step("rdm", "#tools_next")
pick("installed", "r")
pick("installed", "rstudio")
pick("git_today", "rstudio_pane")
pick("preferred_setup", "rstudio")
pick("ai_tools", "none")
step("tools", "#experience_next")
pick("prog_general", "own_use")
pick("prog_r", "own_use")
pick("prog_python", "few_lines")
pick("cli_usage", "occasional")
pick("git_experience", "occasional")
step("experience", "#goals_next")
set_text("learning_goals", "Test response: pull requests with colleagues")
set_text("teaching_context", "Test response: data stewards at a university library")
js("document.getElementById('goals_next').click();")
t0 <- Sys.time(); done <- FALSE
while (difftime(Sys.time(), t0, units = "secs") < 60) {
  if (grepl("Your answers are saved", js("document.body.innerText"))) { done <- TRUE; break }
  Sys.sleep(0.5)
}
cat(if (done) "ok   end page reached\n" else "FAIL end page\n")
b$close()
quit(status = if (done) 0 else 1)
