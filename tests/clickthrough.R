# Headless click-through of the survey with chromote.
#
# Start the app first, in preview mode, from the project folder:
#   QUARTO_PATH=/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto \
#     Rscript -e 'shiny::runApp("app.R", port = 8765, launch.browser = FALSE)'
# Open one throwaway session after each change to survey.qmd (re-parse
# gotcha), then run:
#   Rscript tests/clickthrough.R [url]
#
# Checks: every page loads without duplicate ids, the conditional text
# fields appear only for their answers and block Next only while visible,
# the consent page comes first and blocks without the box, the email and
# username checks refuse bad input (also for the username of an account
# created during the survey), "none" together with other picks is refused,
# the optional fields never block, and one full response reaches the end
# page. Test answers use the address test@example.org.

library(chromote)

url <- commandArgs(TRUE)[1]
if (is.na(url)) url <- "http://127.0.0.1:8765"

b <- ChromoteSession$new()
js <- function(x) b$Runtime$evaluate(x, returnByValue = TRUE)$result$value
fails <- character(0)
check <- function(ok, what) {
  cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "")
  if (!isTRUE(ok)) fails <<- c(fails, what)
}

visible <- function(sel) {
  isTRUE(js(sprintf(
    "(function(){var e=document.querySelector('%s');return !!(e && e.offsetParent!==null);})()",
    sel
  )))
}
wait_for <- function(sel, timeout = 20) {
  t0 <- Sys.time()
  while (difftime(Sys.time(), t0, units = "secs") < timeout) {
    if (visible(sel)) return(TRUE)
    Sys.sleep(0.25)
  }
  FALSE
}
set_text <- function(id, value) {
  js(sprintf(
    "$('#%s').val(%s).trigger('input').trigger('change');",
    id, jsonlite::toJSON(value, auto_unbox = TRUE)
  ))
  Sys.sleep(0.4)
}
pick <- function(name, value) {
  js(sprintf(
    "document.querySelector('input[name=\"%s\"][value=\"%s\"]').click();",
    name, value
  ))
  Sys.sleep(0.4)
}
shown <- function(id) visible(sprintf("#container-%s", id))
no_duplicate_ids <- function() {
  d <- js("(function(){var s={},d=[];document.querySelectorAll('[id]').forEach(function(e){if(s[e.id])d.push(e.id);s[e.id]=1});return d.join(',');})()")
  identical(d, "")
}
# Click Next and report whether the next page appeared
go_next <- function(page, next_sel, timeout = 20) {
  js(sprintf("document.getElementById('%s_next').click();", page))
  wait_for(next_sel, timeout)
}
# Click Next and report whether the page stayed (Next refused)
blocked <- function(page) {
  js(sprintf("document.getElementById('%s_next').click();", page))
  Sys.sleep(2)
  visible(sprintf("#%s_next", page))
}

invisible(b$Page$navigate(url))
check(wait_for("#start_next", 30), "start page loads")
check(no_duplicate_ids(), "start: no duplicate ids")
check(!grepl("Duplicate IDs", js("document.body.innerText")), "start: no duplicate id error")

# Page agreement (consent first, so nothing is stored without it)
check(go_next("start", "#agreement_next"), "start -> agreement")
check(no_duplicate_ids(), "agreement: no duplicate ids")
check(blocked("agreement"), "missing consent blocks Next")
pick("consent", "yes")
check(go_next("agreement", "#about_next"), "agreement -> about")

# Page about
check(no_duplicate_ids(), "about: no duplicate ids")
check(!shown("github_username"), "github_username hidden at first")
check(!shown("github_username_new"), "github_username_new hidden at first")
check(!shown("os_other"), "os_other hidden at first")
check(!shown("role_other"), "role_other hidden at first")
set_text("email", "not-an-email")
pick("github_account", "yes")
check(shown("github_username"), "github_username shown for 'Yes'")
check(!shown("github_username_new"), "github_username_new hidden for 'Yes'")
pick("github_account", "no")
check(shown("github_username_new"), "github_username_new shown for 'No'")
check(!shown("github_username"), "github_username hidden for 'No'")
pick("github_account", "dont_know")
check(shown("github_username_new"), "github_username_new shown for 'I don't know'")
set_text("github_username_new", "@bad name")
pick("os", "other")
check(shown("os_other"), "os_other shown for 'Another one'")
pick("install_rights", "yes")
pick("role", "other")
check(shown("role_other"), "role_other shown for 'Another role'")
pick("teaches_git", "plan")
check(blocked("about"), "bad email, bad new username and empty other fields block Next")
set_text("email", "test@example.org")
set_text("github_username_new", "octocat-new")
check(blocked("about"), "empty os_other and role_other still block Next")
pick("os", "macos")
check(!shown("os_other"), "os_other hidden again for macOS")
set_text("role_other", "Test role")
pick("github_account", "yes")
check(!shown("github_username_new"), "github_username_new hidden again for 'Yes'")
set_text("github_username", "@bad name")
check(blocked("about"), "bad GitHub username blocks Next")
set_text("github_username", "octocat")
check(go_next("about", "#rdm_next"), "about -> rdm")

# Page rdm
check(no_duplicate_ids(), "rdm: no duplicate ids")
check(!shown("rdm_level_other"), "rdm_level_other hidden at first")
pick("rdm_level", "other")
check(shown("rdm_level_other"), "rdm_level_other shown for 'Somewhere else'")
pick("rdm_activities", "training")
pick("rdm_activities", "none")
check(blocked("rdm"), "'None of these' plus an activity blocks Next")
pick("rdm_activities", "none")
check(blocked("rdm"), "empty rdm_level_other blocks Next")
pick("rdm_level", "group")
check(!shown("rdm_level_other"), "rdm_level_other hidden again for 'group'")
check(go_next("rdm", "#tools_next"), "rdm -> tools")

# Page tools
check(no_duplicate_ids(), "tools: no duplicate ids")
pick("installed", "rstudio")
pick("installed", "none")
pick("git_today", "cli")
pick("preferred_setup", "no_preference")
check(blocked("tools"), "'None of these' plus installed software blocks Next")
pick("installed", "none")
pick("installed", "r")
pick("git_today", "not_at_all")
check(blocked("tools"), "'Not at all' plus a Git way blocks Next")
pick("git_today", "not_at_all")
check(!shown("ai_tools_other"), "ai_tools_other hidden at first")
pick("ai_tools", "claude")
pick("ai_tools", "none")
check(blocked("tools"), "'None of the above' plus an AI tool blocks Next")
pick("ai_tools", "none")
pick("ai_tools", "other")
check(shown("ai_tools_other"), "ai_tools_other shown for 'Other'")
check(blocked("tools"), "empty ai_tools_other blocks Next")
set_text("ai_tools_other", "Le Chat")
check(go_next("tools", "#experience_next"), "tools -> experience")

# Page experience
check(no_duplicate_ids(), "experience: no duplicate ids")
check(blocked("experience"), "empty matrix blocks Next")
pick("prog_general", "few_lines")
pick("prog_r", "own_use")
pick("prog_python", "none")
pick("cli_usage", "occasional")
pick("git_experience", "never")
check(go_next("experience", "#goals_next"), "experience -> goals")

# Page goals
check(no_duplicate_ids(), "goals: no duplicate ids")
check(blocked("goals"), "empty learning_goals blocks Next")
set_text("learning_goals", "Test answer: understand branches")
js("document.getElementById('goals_next').click();")
t0 <- Sys.time()
reached <- FALSE
while (difftime(Sys.time(), t0, units = "secs") < 20) {
  if (grepl("Your answers are saved", js("document.body.innerText"))) { reached <- TRUE; break }
  Sys.sleep(0.25)
}
check(reached, "goals -> end (teaching_context optional)")

b$close()

if (file.exists("preview_data.csv")) {
  d <- utils::read.csv("preview_data.csv")
  row <- d[d$email %in% "test@example.org", , drop = FALSE]
  check(nrow(row) >= 1, "preview_data.csv holds the test response")
  if (nrow(row) >= 1) {
    r <- row[nrow(row), ]
    check(identical(as.character(r$consent), "yes"), "stored consent is yes")
    check(identical(as.character(r$github_username), "octocat"), "stored github_username")
    check(identical(as.character(r$preferred_setup), "no_preference"), "stored preferred_setup")
    check(grepl("own_use", r$prog_r), "stored prog_r")
    check(!any(c("ip_address", "browser") %in% names(d)), "no IP address or browser stored")
  }
} else {
  check(FALSE, "preview_data.csv exists (run from the project folder)")
}

cat("\n", length(fails), " failure(s)\n", sep = "")
quit(status = if (length(fails)) 1 else 0)
